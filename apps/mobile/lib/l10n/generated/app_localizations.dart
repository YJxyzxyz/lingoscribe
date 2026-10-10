import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @libraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to open your library'**
  String get libraryUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @recordingRecovered.
  ///
  /// In en, this message translates to:
  /// **'The task was interrupted. Your audio is available; you can retry transcription.'**
  String get recordingRecovered;

  /// No description provided for @finishCurrentTask.
  ///
  /// In en, this message translates to:
  /// **'Finish the current task first.'**
  String get finishCurrentTask;

  /// No description provided for @microphonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required to record. Allow it in system settings.'**
  String get microphonePermission;

  /// No description provided for @recordingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto-save could not finish. Try stopping the recording, or restart the app to recover the local audio.'**
  String get recordingSaveFailed;

  /// No description provided for @preparingRecording.
  ///
  /// In en, this message translates to:
  /// **'Preparing to record'**
  String get preparingRecording;

  /// No description provided for @recordingInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Recording was interrupted. The local audio was recovered and can be transcribed.'**
  String get recordingInterrupted;

  /// No description provided for @recordingIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Recording did not finish correctly. Check microphone access before recording again.'**
  String get recordingIncomplete;

  /// No description provided for @importingAudio.
  ///
  /// In en, this message translates to:
  /// **'Importing audio'**
  String get importingAudio;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file exceeds 2 GB. Trim the audio before importing.'**
  String get fileTooLarge;

  /// No description provided for @preserveEditsBeforeRetry.
  ///
  /// In en, this message translates to:
  /// **'Use “Transcribe a new copy” to keep your existing edits.'**
  String get preserveEditsBeforeRetry;

  /// No description provided for @prepareModelFirst.
  ///
  /// In en, this message translates to:
  /// **'Download or import a model in Offline models to transcribe on your device.'**
  String get prepareModelFirst;

  /// No description provided for @verifyingLocalModel.
  ///
  /// In en, this message translates to:
  /// **'Verifying the local model'**
  String get verifyingLocalModel;

  /// No description provided for @preparingAudio.
  ///
  /// In en, this message translates to:
  /// **'Preparing audio'**
  String get preparingAudio;

  /// No description provided for @transcribingOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Transcribing on your device'**
  String get transcribingOnDevice;

  /// No description provided for @loadingLocalModel.
  ///
  /// In en, this message translates to:
  /// **'Loading the local model'**
  String get loadingLocalModel;

  /// No description provided for @checkingSpeechGaps.
  ///
  /// In en, this message translates to:
  /// **'Checking for missed speech'**
  String get checkingSpeechGaps;

  /// No description provided for @detectingSpeech.
  ///
  /// In en, this message translates to:
  /// **'Detecting speech'**
  String get detectingSpeech;

  /// No description provided for @transcriptionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Transcription cancelled. Your audio has been kept.'**
  String get transcriptionCancelled;

  /// No description provided for @preparingRevision.
  ///
  /// In en, this message translates to:
  /// **'Preparing a new transcription'**
  String get preparingRevision;

  /// No description provided for @taskInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The task was interrupted. Your audio has been kept; please retry.'**
  String get taskInterrupted;

  /// No description provided for @detectorIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'The built-in speech detector failed its integrity check.'**
  String get detectorIntegrityFailed;

  /// No description provided for @exportText.
  ///
  /// In en, this message translates to:
  /// **'Plain text · TXT'**
  String get exportText;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Notes · Markdown'**
  String get exportMarkdown;

  /// No description provided for @exportSrt.
  ///
  /// In en, this message translates to:
  /// **'Subtitles · SRT'**
  String get exportSrt;

  /// No description provided for @exportVtt.
  ///
  /// In en, this message translates to:
  /// **'Web subtitles · VTT'**
  String get exportVtt;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Full data · JSON'**
  String get exportJson;

  /// No description provided for @baseModel.
  ///
  /// In en, this message translates to:
  /// **'Light · Base'**
  String get baseModel;

  /// No description provided for @baseModelDescription.
  ///
  /// In en, this message translates to:
  /// **'A smaller download for short notes. Multilingual, Q5 quantized.'**
  String get baseModelDescription;

  /// No description provided for @smallModel.
  ///
  /// In en, this message translates to:
  /// **'Detailed · Small'**
  String get smallModel;

  /// No description provided for @smallModelDescription.
  ///
  /// In en, this message translates to:
  /// **'A larger multilingual model for interviews and bilingual audio. Speed and memory use depend on your device.'**
  String get smallModelDescription;

  /// No description provided for @modelIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'Model verification failed. Download the official model again.'**
  String get modelIntegrityFailed;

  /// No description provided for @modelRequired.
  ///
  /// In en, this message translates to:
  /// **'Download or import a model first.'**
  String get modelRequired;

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get downloadCancelled;

  /// No description provided for @modelSizeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The model file has an unexpected size.'**
  String get modelSizeInvalid;

  /// No description provided for @waitForModelOperation.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current model operation to finish.'**
  String get waitForModelOperation;

  /// No description provided for @officialModelsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the official Base / Small Q5 models listed here are supported.'**
  String get officialModelsOnly;

  /// No description provided for @applicationTitle.
  ///
  /// In en, this message translates to:
  /// **'LingoScribe'**
  String get applicationTitle;

  /// No description provided for @onboardingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your voice stays here.\nYour words go with you.'**
  String get onboardingHeadline;

  /// No description provided for @onboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'Turn recordings into text you can replay and edit.\nChinese, English and bilingual audio, transcribed on your device.'**
  String get onboardingDescription;

  /// No description provided for @noAccountNoAds.
  ///
  /// In en, this message translates to:
  /// **'No account · No audio uploads · No ads'**
  String get noAccountNoAds;

  /// No description provided for @firstModelExplanation.
  ///
  /// In en, this message translates to:
  /// **'Download a model once, or import an official model file. Then transcribe offline. Results depend on your device and recording quality.'**
  String get firstModelExplanation;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started  →'**
  String get getStarted;

  /// No description provided for @recordingConsent.
  ///
  /// In en, this message translates to:
  /// **'Get participants’ consent before recording.'**
  String get recordingConsent;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @exportThisTranscript.
  ///
  /// In en, this message translates to:
  /// **'Export this transcript'**
  String get exportThisTranscript;

  /// No description provided for @shareExplanation.
  ///
  /// In en, this message translates to:
  /// **'Files are sent to other apps only when you choose to share.'**
  String get shareExplanation;

  /// No description provided for @deleteTranscriptQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete audio and transcript?'**
  String get deleteTranscriptQuestion;

  /// No description provided for @deleteTranscriptExplanation.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Copies already shared with other apps will remain.'**
  String get deleteTranscriptExplanation;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @replayAndEdit.
  ///
  /// In en, this message translates to:
  /// **'Replay & edit'**
  String get replayAndEdit;

  /// No description provided for @exportTranscript.
  ///
  /// In en, this message translates to:
  /// **'Export transcript'**
  String get exportTranscript;

  /// No description provided for @transcribeNewCopy.
  ///
  /// In en, this message translates to:
  /// **'Transcribe a new copy'**
  String get transcribeNewCopy;

  /// No description provided for @deleteAudioAndTranscript.
  ///
  /// In en, this message translates to:
  /// **'Delete audio and transcript'**
  String get deleteAudioAndTranscript;

  /// No description provided for @preparingTranscription.
  ///
  /// In en, this message translates to:
  /// **'Preparing transcription'**
  String get preparingTranscription;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @searchThisTranscript.
  ///
  /// In en, this message translates to:
  /// **'Search this transcript'**
  String get searchThisTranscript;

  /// No description provided for @bookmarksOnly.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks only'**
  String get bookmarksOnly;

  /// No description provided for @noSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'No speech detected'**
  String get noSpeechDetected;

  /// No description provided for @audioKeptLocally.
  ///
  /// In en, this message translates to:
  /// **'Your audio is stored here'**
  String get audioKeptLocally;

  /// No description provided for @checkAudioQuality.
  ///
  /// In en, this message translates to:
  /// **'Replay the audio to check for clear speech.'**
  String get checkAudioQuality;

  /// No description provided for @transcribeWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Prepare a model, then turn this audio into text.'**
  String get transcribeWhenReady;

  /// No description provided for @startOfflineTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcribe offline'**
  String get startOfflineTranscription;

  /// No description provided for @noModelInstalled.
  ///
  /// In en, this message translates to:
  /// **'No model installed. Download or import one in Offline models.'**
  String get noModelInstalled;

  /// No description provided for @noMatchingSegments.
  ///
  /// In en, this message translates to:
  /// **'No matching segments'**
  String get noMatchingSegments;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @bookmarkSegment.
  ///
  /// In en, this message translates to:
  /// **'Bookmark segment'**
  String get bookmarkSegment;

  /// No description provided for @editSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit segment'**
  String get editSegment;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get edited;

  /// No description provided for @pausePlayback.
  ///
  /// In en, this message translates to:
  /// **'Pause playback'**
  String get pausePlayback;

  /// No description provided for @playAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// No description provided for @tapTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Tap a timestamp to hear the audio'**
  String get tapTimestamp;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @offlineModels.
  ///
  /// In en, this message translates to:
  /// **'Offline models'**
  String get offlineModels;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'LingoScribe'**
  String get brandName;

  /// No description provided for @transcriptionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Transcription preferences'**
  String get transcriptionPreferences;

  /// No description provided for @yourAudioLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your audio library'**
  String get yourAudioLibrary;

  /// No description provided for @searchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search titles or transcripts'**
  String get searchLibrary;

  /// No description provided for @allRecords.
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get allRecords;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResults;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get startRecording;

  /// No description provided for @importAudio.
  ///
  /// In en, this message translates to:
  /// **'Import audio'**
  String get importAudio;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'A home for your voice'**
  String get emptyLibraryTitle;

  /// No description provided for @noRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get noRecordsFound;

  /// No description provided for @emptyLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Record a thought or import an interview.\nYour audio and text stay on your device.'**
  String get emptyLibraryDescription;

  /// No description provided for @tryAnotherKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try a different keyword.'**
  String get tryAnotherKeyword;

  /// No description provided for @prepareOfflineModel.
  ///
  /// In en, this message translates to:
  /// **'Prepare an offline model'**
  String get prepareOfflineModel;

  /// No description provided for @statusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get statusRecording;

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'Audio saved · Ready to transcribe'**
  String get statusSaved;

  /// No description provided for @statusTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing locally'**
  String get statusTranscribing;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Transcription complete'**
  String get statusReady;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed · Retry available'**
  String get statusFailed;

  /// No description provided for @statusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted · Audio kept'**
  String get statusInterrupted;

  /// No description provided for @deleteModelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this model?'**
  String get deleteModelQuestion;

  /// No description provided for @deleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get deleteModel;

  /// No description provided for @modelsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Keep AI on your device'**
  String get modelsHeadline;

  /// No description provided for @modelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Download once. Use offline.\nModels process local audio; recordings are never uploaded.'**
  String get modelsDescription;

  /// No description provided for @modelVerificationExplanation.
  ///
  /// In en, this message translates to:
  /// **'Each model is checked with SHA-256 before installation, then checked again before transcription.'**
  String get modelVerificationExplanation;

  /// No description provided for @importOfficialModel.
  ///
  /// In en, this message translates to:
  /// **'Import an official model file'**
  String get importOfficialModel;

  /// No description provided for @useModelMirror.
  ///
  /// In en, this message translates to:
  /// **'Use an alternative download source'**
  String get useModelMirror;

  /// No description provided for @modelSourceExplanation.
  ///
  /// In en, this message translates to:
  /// **'Default: Hugging Face. Alternative: hf-mirror.com. The source receives your IP and model request, never your recordings.'**
  String get modelSourceExplanation;

  /// No description provided for @modelAccuracyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Accuracy depends on recording quality, language and model. Larger models usually need more memory and time. Speed has not been measured on this device.'**
  String get modelAccuracyExplanation;

  /// No description provided for @verifyingModel.
  ///
  /// In en, this message translates to:
  /// **'Verifying model…'**
  String get verifyingModel;

  /// No description provided for @currentModel.
  ///
  /// In en, this message translates to:
  /// **'Currently selected'**
  String get currentModel;

  /// No description provided for @selectModel.
  ///
  /// In en, this message translates to:
  /// **'Use this model'**
  String get selectModel;

  /// No description provided for @discardRecordingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard this recording?'**
  String get discardRecordingQuestion;

  /// No description provided for @discardRecordingExplanation.
  ///
  /// In en, this message translates to:
  /// **'This recording will be deleted. You can go back and save it instead.'**
  String get discardRecordingExplanation;

  /// No description provided for @resumeRecording.
  ///
  /// In en, this message translates to:
  /// **'Resume recording'**
  String get resumeRecording;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get listening;

  /// No description provided for @pausedRecording.
  ///
  /// In en, this message translates to:
  /// **'Paused · Tap to resume'**
  String get pausedRecording;

  /// No description provided for @recordingMoment.
  ///
  /// In en, this message translates to:
  /// **'Capture this moment'**
  String get recordingMoment;

  /// No description provided for @pauseRecording.
  ///
  /// In en, this message translates to:
  /// **'Pause recording'**
  String get pauseRecording;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @stopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop & save'**
  String get stopAndSave;

  /// No description provided for @backgroundPauseExplanation.
  ///
  /// In en, this message translates to:
  /// **'Recording pauses in the background.\nUp to two hours; saved automatically near the limit.\nSave, then transcribe offline.'**
  String get backgroundPauseExplanation;

  /// No description provided for @settingsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Make it your own'**
  String get settingsHeadline;

  /// No description provided for @newAudioDefaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults for new recordings and imports'**
  String get newAudioDefaults;

  /// No description provided for @audioLanguage.
  ///
  /// In en, this message translates to:
  /// **'Audio language'**
  String get audioLanguage;

  /// No description provided for @autoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Detect automatically · Includes Chinese & English'**
  String get autoLanguage;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @glossaryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Glossary prompt'**
  String get glossaryPrompt;

  /// No description provided for @glossaryHint.
  ///
  /// In en, this message translates to:
  /// **'For example: LingoScribe, product names, people, technical terms'**
  String get glossaryHint;

  /// No description provided for @glossaryExplanation.
  ///
  /// In en, this message translates to:
  /// **'Terms guide the model but do not guarantee a result. Saved records keep their original settings.'**
  String get glossaryExplanation;

  /// No description provided for @privacyByDefault.
  ///
  /// In en, this message translates to:
  /// **'Privacy by default'**
  String get privacyByDefault;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Recording, imported audio, transcription and search are processed locally. There are no accounts, ads or analytics SDKs, and this content is never uploaded.\n\nInternet access is used only when you download a model. When you export and share, the receiving app handles the file under its own privacy rules.\n\nData is stored in the system app sandbox, without additional app-level encryption. Uninstalling deletes local records. Export important content first.'**
  String get privacyDescription;

  /// No description provided for @clearExportCache.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary exports'**
  String get clearExportCache;

  /// No description provided for @exportCacheExplanation.
  ///
  /// In en, this message translates to:
  /// **'Keeps recordings and your library. Shared copies remain.'**
  String get exportCacheExplanation;

  /// No description provided for @noTemporaryExports.
  ///
  /// In en, this message translates to:
  /// **'No temporary exports'**
  String get noTemporaryExports;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @licenseApplicationName.
  ///
  /// In en, this message translates to:
  /// **'LingoScribe'**
  String get licenseApplicationName;

  /// No description provided for @usageReminder.
  ///
  /// In en, this message translates to:
  /// **'Get participants’ consent before recording. AI can make mistakes; replay important details to check them. Keep the app in the foreground during transcription. Consider connecting power for long audio.'**
  String get usageReminder;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @transcriptText.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcriptText;

  /// No description provided for @enterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get enterTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @brandSemantics.
  ///
  /// In en, this message translates to:
  /// **'LingoScribe logo'**
  String get brandSemantics;

  /// No description provided for @onYourDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Only on your device'**
  String get onYourDeviceOnly;

  /// No description provided for @recordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 record} other{{count} records}}'**
  String recordCount(int count);

  /// No description provided for @proofreadAt.
  ///
  /// In en, this message translates to:
  /// **'Edit {time}'**
  String proofreadAt(String time);

  /// No description provided for @originalTranscript.
  ///
  /// In en, this message translates to:
  /// **'Original: {text}'**
  String originalTranscript(String text);

  /// No description provided for @removeModelExplanation.
  ///
  /// In en, this message translates to:
  /// **'Free {size}. Recordings and transcripts stay. You can download the model again.'**
  String removeModelExplanation(String size);

  /// No description provided for @downloadModelSize.
  ///
  /// In en, this message translates to:
  /// **'Download {size}'**
  String downloadModelSize(String size);

  /// No description provided for @downloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String downloadProgress(String percent);

  /// No description provided for @modelLanguagesAndLicense.
  ///
  /// In en, this message translates to:
  /// **'{size} · Chinese / English · MIT'**
  String modelLanguagesAndLicense(String size);

  /// No description provided for @exportFilesCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 temporary export cleared} other{{count} temporary exports cleared}}'**
  String exportFilesCleared(int count);

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get interfaceLanguage;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get followSystem;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed. Please retry.'**
  String get operationFailed;

  /// No description provided for @audioUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Unable to read audio. Check that the file contains an audio track in a supported format.'**
  String get audioUnreadable;

  /// No description provided for @audioTooLong.
  ///
  /// In en, this message translates to:
  /// **'Audio must be shorter than two hours. Trim it first.'**
  String get audioTooLong;

  /// No description provided for @storageFull.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage. Free some space and retry.'**
  String get storageFull;

  /// No description provided for @modelConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the model source. Try the alternative source or import a model file.'**
  String get modelConnectionFailed;

  /// No description provided for @modelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the model. Check its integrity or try the light model.'**
  String get modelLoadFailed;

  /// No description provided for @fileAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to access the file. Select it again and allow access.'**
  String get fileAccessFailed;

  /// No description provided for @engineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the transcription engine. Update the app and retry.'**
  String get engineUnavailable;

  /// No description provided for @recordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording {date} {time}'**
  String recordingTitle(String date, String time);

  /// No description provided for @recordingRequiresForeground.
  ///
  /// In en, this message translates to:
  /// **'Return to the app before starting a recording.'**
  String get recordingRequiresForeground;

  /// No description provided for @recordingStartFailedAudioKept.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start. Any captured audio was kept in your library.'**
  String get recordingStartFailedAudioKept;

  /// No description provided for @revisionTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} · New transcription'**
  String revisionTitle(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
