import 'package:flutter_test/flutter_test.dart';
import 'package:zentrip/l10n/app_localizations_ar.dart';
import 'package:zentrip/l10n/app_localizations_en.dart';

void main() {
  test('Zen AI labels and connected status use the requested wording', () {
    final arabic = AppLocalizationsAr();
    final english = AppLocalizationsEn();

    expect(arabic.navChatbot, 'Zen AI');
    expect(arabic.chatbotTitle, 'Zen AI');
    expect(arabic.startPlanningWithZen, contains('Zen AI'));
    expect(arabic.zenMessages, contains('Zen AI'));
    expect(arabic.onboardingDesc1, contains('Zen AI'));
    expect(arabic.chatbotWelcome, contains('Zen AI'));
    expect(arabic.chatbotInputHint, contains('Zen AI'));
    expect(arabic.noChatHistorySubtitle, contains('Zen AI'));
    expect(arabic.zenTyping, contains('Zen AI'));
    expect(arabic.chatOnlineStatus, 'متصل');
    expect(english.navChatbot, 'Zen AI');
    expect(english.chatbotTitle, 'Zen AI');
    expect(english.startPlanningWithZen, contains('Zen AI'));
    expect(english.zenMessages, contains('Zen AI'));
    expect(english.onboardingDesc1, contains('Zen AI'));
    expect(english.chatOnlineStatus, 'Connected');
  });
}
