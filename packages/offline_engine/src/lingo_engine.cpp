#include "lingo_engine.h"
#include "whisper.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
struct Job {
    std::string model, wav, language, prompt, result, vad;
    int threads;
    std::atomic<bool> cancel{false};
    std::atomic<int> progress{0};
    std::atomic<int> phase{0};
    double completed = 0, chunk = 0, total = 1;
};
std::string quote(const std::string &s) {
    std::ostringstream out;
    out << '"';
    const char *hex = "0123456789abcdef";
    for (unsigned char c : s) {
        if (c == '"' || c == '\\') out << '\\' << c;
        else if (c < 32) out << "\\u00" << hex[c >> 4] << hex[c & 15];
        else out << c;
    }
    out << '"';
    return out.str();
}
uint32_t u32(std::ifstream &f) {
    unsigned char b[4];
    if (!f.read(reinterpret_cast<char *>(b), 4)) throw std::runtime_error("Truncated WAV");
    return uint32_t(b[0]) | uint32_t(b[1]) << 8 | uint32_t(b[2]) << 16 | uint32_t(b[3]) << 24;
}
struct Wave {
    std::ifstream f;
    uint32_t samples = 0;
    explicit Wave(const std::string &path) : f(path, std::ios::binary) {
        char id[4];
        if (!f.read(id, 4) || std::memcmp(id, "RIFF", 4)) throw std::runtime_error("Expected RIFF WAV");
        u32(f);
        if (!f.read(id, 4) || std::memcmp(id, "WAVE", 4)) throw std::runtime_error("Expected WAVE");
        bool format = false;
        while (f.read(id, 4)) {
            const auto size = u32(f);
            const auto start = f.tellg();
            if (!std::memcmp(id, "fmt ", 4)) {
                if (size < 16) throw std::runtime_error("Invalid WAV format");
                auto typeChannels = u32(f), rate = u32(f);
                u32(f);
                auto blockBits = u32(f);
                if ((typeChannels & 65535) != 1 || (typeChannels >> 16) != 1 || rate != 16000 || (blockBits >> 16) != 16 || (blockBits & 65535) != 2)
                    throw std::runtime_error("Audio must be 16 kHz mono PCM16 WAV");
                format = true;
            } else if (!std::memcmp(id, "data", 4)) {
                if (!format || size % 2 || size == 0 || size > 16000u * 2u * 7200u)
                    throw std::runtime_error("Invalid or over-two-hour WAV");
                const auto dataStart = f.tellg();
                f.seekg(0, std::ios::end);
                if (f.tellg() - dataStart < size) throw std::runtime_error("Truncated audio data");
                f.seekg(dataStart);
                samples = size / 2;
                return;
            }
            f.seekg(start + std::streamoff(size + (size & 1)));
        }
        throw std::runtime_error("Missing WAV audio");
    }
};
void quiet(enum ggml_log_level, const char *, void *) {}
bool abort_job(void *p) { return static_cast<Job *>(p)->cancel.load(); }
void progress(whisper_context *, whisper_state *, int value, void *p) {
    auto *j = static_cast<Job *>(p);
    const int next = std::clamp(int((j->completed + j->chunk * value / 100.0) / j->total * 100), 0, 99);
    int current = j->progress.load();
    while (next > current && !j->progress.compare_exchange_weak(current, next)) {}
}
}

extern "C" {
const char *ls_version(void) { return "LingoScribe/0.1 whisper.cpp/1.9.4"; }
void *ls_job_create(const char *model, const char *wav, const char *language, const char *prompt, int32_t threads) {
    try {
        if (!model || !wav || !language || !prompt) return nullptr;
        auto *j = new Job;
        j->model = model; j->wav = wav; j->language = language; j->prompt = prompt;
        j->threads = std::clamp(int(threads), 1, 4);
        return j;
    } catch (...) { return nullptr; }
}
int32_t ls_job_run(void *handle) {
    auto *j = static_cast<Job *>(handle);
    if (!j) return -1;
    try {
        Wave wav(j->wav);
        if (j->cancel.load()) throw std::runtime_error("cancelled");
        // Never log user audio, prompts or transcript text to device logs.
        whisper_log_set(quiet, nullptr);
        auto cp = whisper_context_default_params();
        cp.use_gpu = false; // CPU baseline, benchmark GPU separately before release.
        std::unique_ptr<whisper_context, decltype(&whisper_free)> ctx(
            whisper_init_from_file_with_params(j->model.c_str(), cp), &whisper_free);
        if (!ctx) throw std::runtime_error("Unable to load model; check model integrity and available memory");
        std::unique_ptr<whisper_vad_context, decltype(&whisper_vad_free)> vad(nullptr, &whisper_vad_free);
        if (!j->vad.empty()) {
            auto vp = whisper_vad_default_context_params(); vp.n_threads = std::min(j->threads, 2); vp.use_gpu = false;
            vad.reset(whisper_vad_init_from_file_with_params(j->vad.c_str(), vp));
            if (!vad) throw std::runtime_error("Unable to load bundled speech detector");
        }
        if (j->language != "auto" && whisper_lang_id(j->language.c_str()) < 0) throw std::runtime_error("Unsupported language");
        j->total = wav.samples;
        std::ostringstream json;
        json << "{\"segments\":[";
        bool first = true;
        uint32_t position = 0;
        int64_t lastEnd = 0;
        while (position < wav.samples) {
            if (j->cancel.load()) throw std::runtime_error("cancelled");
            // At most five minutes of PCM in memory; choose a quiet boundary near its end.
            const auto count = std::min(16000u * 300u, wav.samples - position);
            std::vector<unsigned char> bytes(count * 2);
            if (!wav.f.read(reinterpret_cast<char *>(bytes.data()), bytes.size())) throw std::runtime_error("Audio read failed");
            std::vector<float> pcm(count);
            for (uint32_t i = 0; i < count; ++i) {
                const auto value = int16_t(uint16_t(bytes[i*2]) | uint16_t(bytes[i*2+1]) << 8);
                pcm[i] = value / 32768.0f;
            }
            uint32_t used = count;
            if (position + count < wav.samples) {
                double best = 1e9;
                for (uint32_t i = count - 32000; i + 1600 <= count; i += 1600) {
                    double energy = 0;
                    for (uint32_t k = i; k < i + 1600; ++k) energy += pcm[k]*pcm[k];
                    if (energy < best) { best = energy; used = i + 800; }
                }
                wav.f.seekg(-std::streamoff((count - used) * 2), std::ios::cur);
            }
            struct Segment { int64_t begin, end; std::string text; };
            std::vector<Segment> segments;
            std::vector<std::pair<uint32_t, uint32_t>> speech;
            if (vad) {
                j->phase.store(4);
                whisper_vad_reset_state(vad.get());
                for (uint32_t window = 0; window < used; window += 16000 * 30) {
                    if (j->cancel.load()) throw std::runtime_error("cancelled");
                    const uint32_t length = std::min(16000u * 30u, used - window);
                    if (!whisper_vad_detect_speech_no_reset(vad.get(), pcm.data() + window, int(length)))
                        throw std::runtime_error("Speech detection failed");
                    auto vp = whisper_vad_default_params(); vp.speech_pad_ms = 80; vp.min_silence_duration_ms = 300;
                    std::unique_ptr<whisper_vad_segments, decltype(&whisper_vad_free_segments)> detected(
                        whisper_vad_segments_from_probs(vad.get(), vp), &whisper_vad_free_segments);
                    if (!detected) throw std::runtime_error("Speech interval extraction failed");
                    for (int i = 0; i < whisper_vad_segments_n_segments(detected.get()); ++i) {
                        const uint32_t a = window + uint32_t(std::max(0.0f, whisper_vad_segments_get_segment_t0(detected.get(), i)) * 160);
                        const uint32_t b = std::min(used, window + uint32_t(std::max(0.0f, whisper_vad_segments_get_segment_t1(detected.get(), i)) * 160));
                        if (b > a) speech.push_back({a, b});
                    }
                }
                if (speech.empty()) { position += used; continue; }
            }
            auto decode = [&](uint32_t spanStart, uint32_t spanCount) {
            j->completed = position + spanStart; j->chunk = spanCount;
            double energy = 0;
            for (uint32_t i = spanStart; i < spanStart + spanCount; ++i) energy += double(pcm[i]) * pcm[i];
            if (energy / spanCount < 1e-8) return;
            if (j->cancel.load()) throw std::runtime_error("cancelled");
            auto params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH);
            params.n_threads = j->threads;
            params.beam_search.beam_size = 3;
            params.language = j->language.c_str();
            params.translate = false;
            params.no_context = true;
            params.initial_prompt = j->prompt.empty() ? nullptr : j->prompt.c_str();
            params.print_progress = params.print_realtime = params.print_timestamps = params.print_special = false;
            params.suppress_nst = true;
            params.abort_callback = abort_job; params.abort_callback_user_data = j;
            params.progress_callback = progress; params.progress_callback_user_data = j;
            if (whisper_full(ctx.get(), params, pcm.data() + spanStart, int(spanCount)) != 0) {
                if (j->cancel.load()) throw std::runtime_error("cancelled");
                throw std::runtime_error("Whisper inference failed");
            }
            for (int i = 0; i < whisper_full_n_segments(ctx.get()); ++i) {
                std::string text = whisper_full_get_segment_text(ctx.get(), i);
#ifdef LS_DEV_DIAGNOSTICS
                std::fprintf(stderr, "LOCAL_QA_ONLY segment=%d t0=%lld t1=%lld text=%s\n", i,
                    (long long)whisper_full_get_segment_t0(ctx.get(), i),
                    (long long)whisper_full_get_segment_t1(ctx.get(), i), text.c_str());
#endif
                if (text.find_first_not_of(" \t\r\n") == std::string::npos) continue;
                int64_t begin = (position + spanStart) / 16 + whisper_full_get_segment_t0(ctx.get(), i) * 10;
                int64_t end = (position + spanStart) / 16 + whisper_full_get_segment_t1(ctx.get(), i) * 10;
                begin = std::max(begin, int64_t((position + spanStart) / 16));
                end = std::min(end, int64_t((position + spanStart + spanCount) / 16));
                if (end <= begin) continue;
                if (vad) {
                    const uint32_t a = uint32_t(std::max<int64_t>(0, begin * 16 - position));
                    const uint32_t b = std::min(used, uint32_t(std::max<int64_t>(0, end * 16 - position)));
                    uint32_t overlap = 0;
                    for (const auto &voice : speech) {
                        if (std::min(b, voice.second) > std::max(a, voice.first)) overlap += std::min(b, voice.second) - std::max(a, voice.first);
                    }
                    if (overlap < 1600) continue;
                }
                segments.push_back({begin, end, std::move(text)});
            }
            };
            j->phase.store(1);
            decode(0, used);
            // A large model can omit another language while leaving a timestamp gap.
            // Only revisit uncovered intervals containing audible signal: the common
            // successful path stays one inference pass, and original segments are retained.
            if (j->language == "auto" && !segments.empty()) {
                const auto primary = segments;
                int64_t cursor = position / 16;
                const int64_t chunkEnd = (position + used) / 16;
                for (size_t gap = 0; gap <= primary.size(); ++gap) {
                    const int64_t next = gap < primary.size() ? primary[gap].begin : chunkEnd;
                    if (next - cursor >= 1000) {
                        const uint32_t a = std::min(used, uint32_t(std::max<int64_t>(0, cursor * 16 - position)));
                        const uint32_t b = std::min(used, uint32_t(std::max<int64_t>(0, next * 16 - position)));
                        uint32_t audible = 0;
                        if (vad) {
                            for (const auto &voice : speech) {
                                if (std::min(b, voice.second) > std::max(a, voice.first)) audible += std::min(b, voice.second) - std::max(a, voice.first);
                            }
                        } else for (uint32_t f = a; f + 320 <= b; f += 320) {
                            double energy = 0;
                            for (uint32_t k = f; k < f + 320; ++k) energy += double(pcm[k]) * pcm[k];
                            if (energy / 320 > 1e-5) audible += 320;
                        }
                        if (audible >= 4800) { j->phase.store(2); decode(a, b - a); }
                    }
                    if (gap < primary.size()) cursor = std::max(cursor, primary[gap].end);
                }
            }
            std::stable_sort(segments.begin(), segments.end(), [](const Segment &a, const Segment &b) { return a.begin < b.begin; });
            for (const auto &segment : segments) {
                const auto begin = std::max(lastEnd, segment.begin);
                const auto end = segment.end;
                if (end <= begin) continue;
                if (!first) json << ',';
                first = false;
                json << "{\"startMs\":" << begin << ",\"endMs\":" << end << ",\"text\":" << quote(segment.text) << '}';
                lastEnd = end;
            }
            position += used;
        }
        if (j->cancel.load()) throw std::runtime_error("cancelled");
        json << "],\"durationMs\":" << wav.samples / 16 << '}';
        j->result = json.str(); j->progress.store(100); j->phase.store(3);
        return 0;
    } catch (const std::exception &e) {
        j->result = "{\"error\":" + quote(e.what()) + "}";
        return j->cancel.load() ? 1 : -1;
    } catch (...) {
        j->result = "{\"error\":\"Native inference failed\"}";
        return -1;
    }
}
int32_t ls_job_progress(void *j) { return j ? static_cast<Job *>(j)->progress.load() : 0; }
int32_t ls_job_phase(void *j) { return j ? static_cast<Job *>(j)->phase.load() : 0; }
void *ls_job_create_v2(const char *model, const char *wav, const char *language, const char *prompt, const char *vad, int32_t threads) {
    auto *job = static_cast<Job *>(ls_job_create(model, wav, language, prompt, threads));
    try { if (job && vad) job->vad = vad; }
    catch (...) { delete job; return nullptr; }
    return job;
}
void ls_job_cancel(void *j) { if (j) static_cast<Job *>(j)->cancel.store(true); }
const char *ls_job_result(void *j) { return j ? static_cast<Job *>(j)->result.c_str() : "{\"error\":\"Invalid job\"}"; }
void ls_job_free(void *j) { delete static_cast<Job *>(j); }
}
