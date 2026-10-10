// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get libraryUnavailable => 'Unable to open your library';

  @override
  String get retry => 'Retry';

  @override
  String get recordingRecovered =>
      'The task was interrupted. Your audio is available; you can retry transcription.';

  @override
  String get finishCurrentTask => 'Finish the current task first.';

  @override
  String get microphonePermission =>
      'Microphone access is required to record. Allow it in system settings.';

  @override
  String get recordingSaveFailed =>
      'Auto-save could not finish. Try stopping the recording, or restart the app to recover the local audio.';

  @override
  String get preparingRecording => 'Preparing to record';

  @override
  String get recordingInterrupted =>
      'Recording was interrupted. The local audio was recovered and can be transcribed.';

  @override
  String get recordingIncomplete =>
      'Recording did not finish correctly. Check microphone access before recording again.';

  @override
  String get importingAudio => 'Importing audio';

  @override
  String get fileTooLarge =>
      'This file exceeds 2 GB. Trim the audio before importing.';

  @override
  String get preserveEditsBeforeRetry =>
      'Use “Transcribe a new copy” to keep your existing edits.';

  @override
  String get prepareModelFirst =>
      'Download or import a model in Offline models to transcribe on your device.';

  @override
  String get verifyingLocalModel => 'Verifying the local model';

  @override
  String get preparingAudio => 'Preparing audio';

  @override
  String get transcribingOnDevice => 'Transcribing on your device';

  @override
  String get loadingLocalModel => 'Loading the local model';

  @override
  String get checkingSpeechGaps => 'Checking for missed speech';

  @override
  String get detectingSpeech => 'Detecting speech';

  @override
  String get transcriptionCancelled =>
      'Transcription cancelled. Your audio has been kept.';

  @override
  String get preparingRevision => 'Preparing a new transcription';

  @override
  String get taskInterrupted =>
      'The task was interrupted. Your audio has been kept; please retry.';

  @override
  String get detectorIntegrityFailed =>
      'The built-in speech detector failed its integrity check.';

  @override
  String get exportText => 'Plain text · TXT';

  @override
  String get exportMarkdown => 'Notes · Markdown';

  @override
  String get exportSrt => 'Subtitles · SRT';

  @override
  String get exportVtt => 'Web subtitles · VTT';

  @override
  String get exportJson => 'Full data · JSON';

  @override
  String get baseModel => 'Light · Base';

  @override
  String get baseModelDescription =>
      'A smaller download for short notes. Multilingual, Q5 quantized.';

  @override
  String get smallModel => 'Detailed · Small';

  @override
  String get smallModelDescription =>
      'A larger multilingual model for interviews and bilingual audio. Speed and memory use depend on your device.';

  @override
  String get modelIntegrityFailed =>
      'Model verification failed. Download the official model again.';

  @override
  String get modelRequired => 'Download or import a model first.';

  @override
  String get downloadCancelled => 'Download cancelled.';

  @override
  String get modelSizeInvalid => 'The model file has an unexpected size.';

  @override
  String get waitForModelOperation =>
      'Wait for the current model operation to finish.';

  @override
  String get officialModelsOnly =>
      'Only the official Base / Small Q5 models listed here are supported.';

  @override
  String get applicationTitle => 'LingoScribe';

  @override
  String get onboardingHeadline =>
      'Your voice stays here.\nYour words go with you.';

  @override
  String get onboardingDescription =>
      'Turn recordings into text you can replay and edit.\nChinese, English and bilingual audio, transcribed on your device.';

  @override
  String get noAccountNoAds => 'No account · No audio uploads · No ads';

  @override
  String get firstModelExplanation =>
      'Download a model once, or import an official model file. Then transcribe offline. Results depend on your device and recording quality.';

  @override
  String get getStarted => 'Get started  →';

  @override
  String get recordingConsent => 'Get participants’ consent before recording.';

  @override
  String get rename => 'Rename';

  @override
  String get exportThisTranscript => 'Export this transcript';

  @override
  String get shareExplanation =>
      'Files are sent to other apps only when you choose to share.';

  @override
  String get deleteTranscriptQuestion => 'Delete audio and transcript?';

  @override
  String get deleteTranscriptExplanation =>
      'This cannot be undone. Copies already shared with other apps will remain.';

  @override
  String get keep => 'Keep';

  @override
  String get delete => 'Delete';

  @override
  String get replayAndEdit => 'Replay & edit';

  @override
  String get exportTranscript => 'Export transcript';

  @override
  String get transcribeNewCopy => 'Transcribe a new copy';

  @override
  String get deleteAudioAndTranscript => 'Delete audio and transcript';

  @override
  String get preparingTranscription => 'Preparing transcription';

  @override
  String get cancel => 'Cancel';

  @override
  String get searchThisTranscript => 'Search this transcript';

  @override
  String get bookmarksOnly => 'Bookmarks only';

  @override
  String get noSpeechDetected => 'No speech detected';

  @override
  String get audioKeptLocally => 'Your audio is stored here';

  @override
  String get checkAudioQuality => 'Replay the audio to check for clear speech.';

  @override
  String get transcribeWhenReady =>
      'Prepare a model, then turn this audio into text.';

  @override
  String get startOfflineTranscription => 'Transcribe offline';

  @override
  String get noModelInstalled =>
      'No model installed. Download or import one in Offline models.';

  @override
  String get noMatchingSegments => 'No matching segments';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get bookmarkSegment => 'Bookmark segment';

  @override
  String get editSegment => 'Edit segment';

  @override
  String get edited => 'Edited';

  @override
  String get pausePlayback => 'Pause playback';

  @override
  String get playAudio => 'Play audio';

  @override
  String get tapTimestamp => 'Tap a timestamp to hear the audio';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get library => 'Library';

  @override
  String get offlineModels => 'Offline models';

  @override
  String get settings => 'Settings';

  @override
  String get brandName => 'LingoScribe';

  @override
  String get transcriptionPreferences => 'Transcription preferences';

  @override
  String get yourAudioLibrary => 'Your audio library';

  @override
  String get searchLibrary => 'Search titles or transcripts';

  @override
  String get allRecords => 'All records';

  @override
  String get searchResults => 'Search results';

  @override
  String get startRecording => 'Record';

  @override
  String get importAudio => 'Import audio';

  @override
  String get emptyLibraryTitle => 'A home for your voice';

  @override
  String get noRecordsFound => 'No records found';

  @override
  String get emptyLibraryDescription =>
      'Record a thought or import an interview.\nYour audio and text stay on your device.';

  @override
  String get tryAnotherKeyword => 'Try a different keyword.';

  @override
  String get prepareOfflineModel => 'Prepare an offline model';

  @override
  String get statusRecording => 'Recording';

  @override
  String get statusSaved => 'Audio saved · Ready to transcribe';

  @override
  String get statusTranscribing => 'Transcribing locally';

  @override
  String get statusReady => 'Transcription complete';

  @override
  String get statusFailed => 'Transcription failed · Retry available';

  @override
  String get statusInterrupted => 'Interrupted · Audio kept';

  @override
  String get deleteModelQuestion => 'Delete this model?';

  @override
  String get deleteModel => 'Delete model';

  @override
  String get modelsHeadline => 'Keep AI on your device';

  @override
  String get modelsDescription =>
      'Download once. Use offline.\nModels process local audio; recordings are never uploaded.';

  @override
  String get modelVerificationExplanation =>
      'Each model is checked with SHA-256 before installation, then checked again before transcription.';

  @override
  String get importOfficialModel => 'Import an official model file';

  @override
  String get useModelMirror => 'Use an alternative download source';

  @override
  String get modelSourceExplanation =>
      'Default: Hugging Face. Alternative: hf-mirror.com. The source receives your IP and model request, never your recordings.';

  @override
  String get modelAccuracyExplanation =>
      'Accuracy depends on recording quality, language and model. Larger models usually need more memory and time. Speed has not been measured on this device.';

  @override
  String get verifyingModel => 'Verifying model…';

  @override
  String get currentModel => 'Currently selected';

  @override
  String get selectModel => 'Use this model';

  @override
  String get discardRecordingQuestion => 'Discard this recording?';

  @override
  String get discardRecordingExplanation =>
      'This recording will be deleted. You can go back and save it instead.';

  @override
  String get resumeRecording => 'Resume recording';

  @override
  String get discard => 'Discard';

  @override
  String get listening => 'Listening';

  @override
  String get pausedRecording => 'Paused · Tap to resume';

  @override
  String get recordingMoment => 'Capture this moment';

  @override
  String get pauseRecording => 'Pause recording';

  @override
  String get saving => 'Saving…';

  @override
  String get stopAndSave => 'Stop & save';

  @override
  String get backgroundPauseExplanation =>
      'Recording pauses in the background.\nUp to two hours; saved automatically near the limit.\nSave, then transcribe offline.';

  @override
  String get settingsHeadline => 'Make it your own';

  @override
  String get newAudioDefaults => 'Defaults for new recordings and imports';

  @override
  String get audioLanguage => 'Audio language';

  @override
  String get autoLanguage =>
      'Detect automatically · Includes Chinese & English';

  @override
  String get chinese => 'Chinese';

  @override
  String get glossaryPrompt => 'Glossary prompt';

  @override
  String get glossaryHint =>
      'For example: LingoScribe, product names, people, technical terms';

  @override
  String get glossaryExplanation =>
      'Terms guide the model but do not guarantee a result. Saved records keep their original settings.';

  @override
  String get privacyByDefault => 'Privacy by default';

  @override
  String get privacyDescription =>
      'Recording, imported audio, transcription and search are processed locally. There are no accounts, ads or analytics SDKs, and this content is never uploaded.\n\nInternet access is used only when you download a model. When you export and share, the receiving app handles the file under its own privacy rules.\n\nData is stored in the system app sandbox, without additional app-level encryption. Uninstalling deletes local records. Export important content first.';

  @override
  String get clearExportCache => 'Clear temporary exports';

  @override
  String get exportCacheExplanation =>
      'Keeps recordings and your library. Shared copies remain.';

  @override
  String get noTemporaryExports => 'No temporary exports';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get licenseApplicationName => 'LingoScribe';

  @override
  String get usageReminder =>
      'Get participants’ consent before recording. AI can make mistakes; replay important details to check them. Keep the app in the foreground during transcription. Consider connecting power for long audio.';

  @override
  String get title => 'Title';

  @override
  String get transcriptText => 'Transcript';

  @override
  String get enterTitle => 'Enter a title';

  @override
  String get save => 'Save';

  @override
  String get brandSemantics => 'LingoScribe logo';

  @override
  String get onYourDeviceOnly => 'Only on your device';

  @override
  String recordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String proofreadAt(String time) {
    return 'Edit $time';
  }

  @override
  String originalTranscript(String text) {
    return 'Original: $text';
  }

  @override
  String removeModelExplanation(String size) {
    return 'Free $size. Recordings and transcripts stay. You can download the model again.';
  }

  @override
  String downloadModelSize(String size) {
    return 'Download $size';
  }

  @override
  String downloadProgress(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String modelLanguagesAndLicense(String size) {
    return '$size · Chinese / English · MIT';
  }

  @override
  String exportFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count temporary exports cleared',
      one: '1 temporary export cleared',
    );
    return '$_temp0';
  }

  @override
  String get interfaceLanguage => 'App language';

  @override
  String get followSystem => 'System default';

  @override
  String get operationFailed =>
      'The operation could not be completed. Please retry.';

  @override
  String get audioUnreadable =>
      'Unable to read audio. Check that the file contains an audio track in a supported format.';

  @override
  String get audioTooLong =>
      'Audio must be shorter than two hours. Trim it first.';

  @override
  String get storageFull => 'Not enough storage. Free some space and retry.';

  @override
  String get modelConnectionFailed =>
      'Unable to reach the model source. Try the alternative source or import a model file.';

  @override
  String get modelLoadFailed =>
      'Unable to load the model. Check its integrity or try the light model.';

  @override
  String get fileAccessFailed =>
      'Unable to access the file. Select it again and allow access.';

  @override
  String get engineUnavailable =>
      'Unable to load the transcription engine. Update the app and retry.';

  @override
  String recordingTitle(String date, String time) {
    return 'Recording $date $time';
  }

  @override
  String get recordingRequiresForeground =>
      'Return to the app before starting a recording.';

  @override
  String get recordingStartFailedAudioKept =>
      'Recording could not start. Any captured audio was kept in your library.';

  @override
  String revisionTitle(String title) {
    return '$title · New transcription';
  }
}
