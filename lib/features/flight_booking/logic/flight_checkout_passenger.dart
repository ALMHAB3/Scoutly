import 'package:flutter/foundation.dart';

/// Passenger age category. Adults and children each need a seat; an infant
/// travels on an adult's lap.
enum FlightTravelerType { adult, child, infant }

/// One traveler's details as entered in Trip Details (same fields as the
/// former Passengers screen) plus the seat chosen for them.
@immutable
class FlightCheckoutPassenger {
  final FlightTravelerType type;
  final String name;
  final String dateOfBirth;
  final String nationality;
  final String passportNumber;
  final String passportExpiry;
  final String email;
  final String phone;

  /// Seat assigned on the deck map; null for infants or when no seat map.
  final String? seat;

  const FlightCheckoutPassenger({
    this.type = FlightTravelerType.adult,
    this.name = '',
    this.dateOfBirth = '',
    this.nationality = '',
    this.passportNumber = '',
    this.passportExpiry = '',
    this.email = '',
    this.phone = '',
    this.seat,
  });

  bool get needsSeat => type != FlightTravelerType.infant;

  FlightCheckoutPassenger copyWith({
    FlightTravelerType? type,
    String? name,
    String? dateOfBirth,
    String? nationality,
    String? passportNumber,
    String? passportExpiry,
    String? email,
    String? phone,
    String? seat,
    bool clearSeat = false,
  }) =>
      FlightCheckoutPassenger(
        type: type ?? this.type,
        name: name ?? this.name,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        nationality: nationality ?? this.nationality,
        passportNumber: passportNumber ?? this.passportNumber,
        passportExpiry: passportExpiry ?? this.passportExpiry,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        seat: clearSeat ? null : (seat ?? this.seat),
      );
}
