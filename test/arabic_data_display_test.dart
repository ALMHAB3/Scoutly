import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/models/attraction_model.dart';
import 'package:scoutly/models/travel_package_model.dart';

void main() {
  group('Arabic catalog presentation', () {
    test('normalizes duplicate bilingual place subtitles', () {
      final place = AttractionModel.fromJson({
        'id': 'red-castle-museum',
        'name': 'Red Castle Museum',
        'name_ar': 'متحف السرايا الحمراء',
        'city': 'Tripoli, Libya',
        'country': 'Libya / ليبيا',
        'location': 'Tripoli, Libya / ليبيا',
      });

      expect(place.displayName('ar'), 'متحف السرايا الحمراء');
      expect(place.displayLocation('ar'), 'طرابلس، ليبيا');
      expect(place.displayLocation('en'), 'Tripoli, Libya');
    });

    test('uses Arabic offer fields and falls back to English when absent', () {
      final offer = TravelPackage.fromJson({
        'id': 'cairo-pharaohs',
        'title': 'Cairo & the Pyramids',
        'title_ar': 'القاهرة والأهرامات',
        'location': 'Cairo',
        'city_ar': 'القاهرة',
        'country': 'Egypt',
        'country_ar': 'مصر',
        'description': 'Explore Cairo.',
        'description_ar': 'اكتشف القاهرة.',
        'highlights': ['Giza Pyramids'],
        'highlights_ar': ['أهرامات الجيزة'],
      });

      expect(offer.displayTitle('ar'), 'القاهرة والأهرامات');
      expect(offer.displayLocation('ar'), 'القاهرة');
      expect(offer.displayCountry('ar'), 'مصر');
      expect(offer.displayDescription('ar'), 'اكتشف القاهرة.');
      expect(offer.displayHighlights('ar'), ['أهرامات الجيزة']);
      expect(offer.displayTitle('en'), 'Cairo & the Pyramids');

      final untranslated = TravelPackage.fromJson({
        'id': 'legacy-offer',
        'title': 'Legacy offer',
        'location': 'Tripoli',
        'country': 'Libya',
      });
      expect(untranslated.displayTitle('ar'), 'Legacy offer');
    });
  });
}
