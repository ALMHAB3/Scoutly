import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/l10n/app_localizations_ar.dart';
import 'package:scoutly/l10n/app_localizations_en.dart';

void main() {
  test('Scoutly AI labels and connected status use the requested wording', () {
    final arabic = AppLocalizationsAr();
    final english = AppLocalizationsEn();

    expect(arabic.navChatbot, 'Scoutly AI');
    expect(arabic.chatbotTitle, 'Scoutly AI');
    expect(arabic.startPlanningWithZen, contains('Scoutly AI'));
    expect(arabic.zenMessages, contains('Scoutly AI'));
    expect(arabic.onboardingDesc1, contains('Scoutly AI'));
    expect(arabic.chatbotWelcome, contains('Scoutly AI'));
    expect(arabic.chatbotInputHint, contains('Scoutly AI'));
    expect(arabic.noChatHistorySubtitle, contains('Scoutly AI'));
    expect(arabic.zenTyping, contains('Scoutly AI'));
    expect(arabic.chatOnlineStatus, 'متصل');
    expect(english.navChatbot, 'Scoutly AI');
    expect(english.chatbotTitle, 'Scoutly AI');
    expect(english.startPlanningWithZen, contains('Scoutly AI'));
    expect(english.zenMessages, contains('Scoutly AI'));
    expect(english.onboardingDesc1, contains('Scoutly AI'));
    expect(english.chatOnlineStatus, 'Connected');
  });
}
