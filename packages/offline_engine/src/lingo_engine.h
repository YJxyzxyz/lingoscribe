#pragma once
#include <stdint.h>
#if defined(_WIN32)
#define LS_API __declspec(dllexport)
#else
#define LS_API __attribute__((visibility("default"))) __attribute__((used))
#endif
#ifdef __cplusplus
extern "C" {
#endif
LS_API const char *ls_version(void);
LS_API void *ls_job_create(const char *model, const char *wav, const char *language, const char *prompt, int32_t threads);
LS_API void *ls_job_create_v2(const char *model, const char *wav, const char *language, const char *prompt, const char *vad, int32_t threads);
LS_API int32_t ls_job_run(void *job);
LS_API int32_t ls_job_progress(void *job);
LS_API int32_t ls_job_phase(void *job);
LS_API void ls_job_cancel(void *job);
LS_API const char *ls_job_result(void *job);
LS_API void ls_job_free(void *job);
#ifdef __cplusplus
}
#endif
