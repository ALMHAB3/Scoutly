import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zentrip/core/constants/currency_rates.dart';
import 'package:zentrip/features/flight_booking/logic/flight_checkout_passenger.dart';
import 'package:zentrip/features/flight_booking/logic/tickets_pdf.dart';
import 'package:zentrip/models/flight_model.dart';

FlightModel _flight() => FlightModel(
      id: '81',
      airline: 'Zentrip Air',
      airlineCode: 'ZT',
      flightNumber: 'ZT 482',
      originCode: 'MRA',
      originCity: 'Misrata',
      destinationCode: 'MJI',
      destinationCity: 'Tripoli',
      departureTime: DateTime(2027, 9, 5, 6, 14),
      arrivalTime: DateTime(2027, 9, 5, 7, 3),
      durationMinutes: 49,
      isDirect: true,
      stops: 0,
      economyPrice: 138,
      seatsAvailable: 24,
    );

String _type(FlightTravelerType t) => t.name;

void main() {
  test('one ticket entry per traveler, each with its own code', () {
    final entries = ticketEntries(
      reference: 'ZT1234',
      travelers: const [
        FlightCheckoutPassenger(name: 'Ali Salem', seat: '12A'),
        FlightCheckoutPassenger(
            type: FlightTravelerType.child, name: 'Sara Ali', seat: '12B'),
        FlightCheckoutPassenger(type: FlightTravelerType.infant, name: 'Omar'),
      ],
      fallbackSeats: const ['12A', '12B'],
      typeLabel: _type,
      onLap: 'On lap',
    );
    expect(entries.map((e) => e.code), ['ZT1234-1', 'ZT1234-2', 'ZT1234-3']);
    expect(entries.map((e) => e.seat), ['12A', '12B', 'On lap']);
    expect(entries.last.typeLabel, 'infant');
  });

  test('single traveler keeps the booking reference as code', () {
    final entries = ticketEntries(
      reference: 'ZT1234',
      travelers: const [],
      fallbackSeats: const ['3C'],
      typeLabel: _type,
      onLap: 'On lap',
      fallbackName: 'Account Holder',
    );
    expect(entries.single.code, 'ZT1234');
    expect(entries.single.seat, '3C');
    expect(entries.single.passengerName, 'Account Holder');
  });

  test('all tickets go into one PDF with a page per traveler', () async {
    final bytes = await buildTicketsPdf(
      flight: _flight(),
      reference: 'ZT1234',
      seatClassLabel: 'Economy',
      totalText: 'LYD 2,227.200',
      rtl: false,
      tickets: const [
        TicketPdfEntry(
            passengerName: 'Ali',
            typeLabel: 'Adult',
            seat: '12A',
            code: 'ZT1234-1'),
        TicketPdfEntry(
            passengerName: 'Sara',
            typeLabel: 'Child',
            seat: '12B',
            code: 'ZT1234-2'),
        TicketPdfEntry(
            passengerName: 'Omar',
            typeLabel: 'Infant',
            seat: 'On lap',
            code: 'ZT1234-3'),
      ],
      labels: TicketPdfLabels(
        title: 'Tickets',
        passenger: 'Passenger',
        seat: 'Seat',
        seatClass: 'Class',
        flight: 'Flight',
        date: 'Date',
        departure: 'Departure',
        arrival: 'Arrival',
        duration: 'Duration',
        reference: 'Reference',
        total: 'Total',
        ticket: 'Ticket',
      ),
    );
    final text = String.fromCharCodes(bytes);
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 3);
  });

  test('Arabic tickets use the bundled Arabic font (works offline)', () async {
    final bytes = await buildTicketsPdf(
      flight: _flight(),
      reference: 'ZT1234',
      seatClassLabel: 'اقتصادية',
      totalText: '2,227.200 د.ل',
      rtl: true,
      locale: 'ar',
      tickets: const [
        TicketPdfEntry(
            passengerName: 'عمر بن علي',
            typeLabel: 'بالغ',
            seat: '12A',
            code: 'ZT1234-1'),
      ],
      labels: TicketPdfLabels(
        title: 'تذاكر',
        passenger: 'المسافر',
        seat: 'المقعد',
        seatClass: 'الدرجة',
        flight: 'الرحلة',
        date: 'التاريخ',
        departure: 'الإقلاع',
        arrival: 'الوصول',
        duration: 'المدة',
        reference: 'رقم الحجز',
        total: 'الإجمالي',
        ticket: 'التذكرة',
      ),
    );
    expect(String.fromCharCodes(bytes), contains('NotoSansArabic'));
    final out = Platform.environment['TICKETS_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('LYD rate ignores invalid admin values', () {
    final before = LydRate.unitsPerUsd;
    LydRate.set(-1);
    LydRate.set(double.nan);
    expect(LydRate.unitsPerUsd, before);
    LydRate.set(7.25);
    expect(LydRate.unitsPerUsd, 7.25);
    LydRate.set(usdToLydRate);
  });

  test('traveler details are serialized for the server', () {
    const p = FlightCheckoutPassenger(
      name: 'Ali Salem',
      dateOfBirth: '1990-01-01',
      nationality: 'Libyan',
      passportNumber: 'AB12345',
      passportExpiry: '2030-01-01',
      seat: '12A',
    );
    expect(p.toJson(), {
      'type': 'adult',
      'name': 'Ali Salem',
      'date_of_birth': '1990-01-01',
      'nationality': 'Libyan',
      'passport_number': 'AB12345',
      'passport_expiry': '2030-01-01',
      'seat': '12A',
    });
  });
}
