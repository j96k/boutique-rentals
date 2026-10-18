double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();
DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);

class AppUser {
  AppUser({required this.id, required this.username, required this.boutiqueName, this.phone});
  final int id;
  final String username;
  final String boutiqueName;
  final String? phone;

  factory AppUser.fromJson(Map<String, dynamic> j) =>
      AppUser(id: j['id'], username: j['username'], boutiqueName: j['boutique_name'], phone: j['phone']);
}

class Rental {
  Rental({
    required this.id,
    required this.clothId,
    required this.clothCode,
    required this.clothName,
    this.clothImage,
    required this.customerName,
    this.customerPhone,
    required this.startAt,
    required this.endAt,
    this.returnedAt,
    required this.rentAmount,
    required this.advancePaid,
    required this.balanceDue,
    required this.depositAmount,
    this.depositReturned,
    required this.depositKept,
    required this.depositStatus,
    this.depositNote,
    this.depositSettledAt,
    this.notes,
    required this.status,
  });

  final int id;
  final int clothId;
  final String clothCode;
  final String clothName;
  final String? clothImage;
  final String customerName;
  final String? customerPhone;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime? returnedAt;
  final double rentAmount; // agreed rent for this booking
  final double advancePaid; // rent paid so far
  final double balanceDue;
  final double depositAmount; // security deposit taken
  final double? depositReturned; // null = not settled yet
  final double depositKept; // kept for damage etc.
  final String depositStatus; // none | held | refunded | part_kept
  final String? depositNote;
  final DateTime? depositSettledAt; // when the deposit was given back
  final String? notes;
  final String status; // booked | on_rent | overdue | returned

  bool get isActive => returnedAt == null;

  factory Rental.fromJson(Map<String, dynamic> j) => Rental(
        id: j['id'],
        clothId: j['cloth_id'],
        clothCode: j['cloth_code'],
        clothName: j['cloth_name'],
        clothImage: j['cloth_image'],
        customerName: j['customer_name'],
        customerPhone: j['customer_phone'],
        startAt: _date(j['start_at'])!,
        endAt: _date(j['end_at'])!,
        returnedAt: _date(j['returned_at']),
        rentAmount: _num(j['rent_amount']),
        advancePaid: _num(j['advance_paid']),
        balanceDue: _num(j['balance_due']),
        depositAmount: _num(j['deposit_amount']),
        depositReturned: j['deposit_returned'] == null ? null : _num(j['deposit_returned']),
        depositKept: _num(j['deposit_kept']),
        depositStatus: j['deposit_status'] ?? 'none',
        depositNote: j['deposit_note'],
        depositSettledAt: _date(j['deposit_settled_at']),
        notes: j['notes'],
        status: j['status'],
      );
}

class Cloth {
  Cloth({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.category,
    this.size,
    required this.rentPrice,
    this.imageUrl,
    required this.status,
    this.currentRental,
    this.nextBooking,
    this.rentals = const [],
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final String? category;
  final String? size;
  final double rentPrice;
  final String? imageUrl;
  final String status; // available | on_rent | overdue
  final Rental? currentRental;
  final Rental? nextBooking;
  final List<Rental> rentals;

  factory Cloth.fromJson(Map<String, dynamic> j) => Cloth(
        id: j['id'],
        code: j['cloth_code'],
        name: j['name'],
        description: j['description'] ?? '',
        category: j['category'],
        size: j['size'],
        rentPrice: _num(j['rent_price']),
        imageUrl: j['image_url'],
        status: j['status'],
        currentRental: j['current_rental'] == null ? null : Rental.fromJson(j['current_rental']),
        nextBooking: j['next_booking'] == null ? null : Rental.fromJson(j['next_booking']),
        rentals: ((j['rentals'] as List?) ?? []).map((e) => Rental.fromJson(e)).toList(),
      );
}

class Dashboard {
  Dashboard({
    required this.total,
    required this.available,
    required this.onRent,
    required this.overdue,
    required this.goingOutToday,
    required this.returningToday,
    required this.overdueList,
    required this.waitlistReady,
  });

  final int total, available, onRent, overdue;
  final List<Rental> goingOutToday, returningToday, overdueList;
  final List<Inquiry> waitlistReady;

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    List<Rental> l(String k) => (j[k] as List).map((e) => Rental.fromJson(e)).toList();
    return Dashboard(
      total: j['total_cloths'],
      available: j['available'],
      onRent: j['on_rent'],
      overdue: j['overdue'],
      goingOutToday: l('going_out_today'),
      returningToday: l('returning_today'),
      overdueList: l('overdue_list'),
      waitlistReady: ((j['waitlist_ready'] as List?) ?? []).map((e) => Inquiry.fromJson(e)).toList(),
    );
  }
}

class BusyRange {
  BusyRange(this.start, this.end);
  final DateTime start, end;
}

class PublicCloth {
  PublicCloth({
    required this.boutiqueName,
    required this.code,
    required this.name,
    required this.description,
    this.category,
    this.size,
    required this.rentPrice,
    this.imageUrl,
    required this.availableNow,
    required this.busy,
  });

  final String boutiqueName, code, name, description;
  final String? category, size, imageUrl;
  final double rentPrice;
  final bool availableNow;
  final List<BusyRange> busy;

  factory PublicCloth.fromJson(Map<String, dynamic> j) => PublicCloth(
        boutiqueName: j['boutique_name'],
        code: j['cloth_code'],
        name: j['name'],
        description: j['description'] ?? '',
        category: j['category'],
        size: j['size'],
        rentPrice: _num(j['rent_price']),
        imageUrl: j['image_url'],
        availableNow: j['available_now'],
        busy: (j['busy'] as List).map((e) => BusyRange(_date(e['start_at'])!, _date(e['end_at'])!)).toList(),
      );
}

/// Someone on the waitlist for a cloth.
class Inquiry {
  Inquiry({
    required this.id,
    required this.clothId,
    required this.clothCode,
    required this.clothName,
    this.clothImage,
    required this.name,
    this.phone,
    this.email,
    this.instagram,
    required this.offeredAmount,
    this.wantedFrom,
    this.wantedTo,
    this.notes,
    required this.status,
    required this.source,
  });

  final int id;
  final int clothId;
  final String clothCode;
  final String clothName;
  final String? clothImage;
  final String name;
  final String? phone;
  final String? email;
  final String? instagram;
  final double offeredAmount;
  final DateTime? wantedFrom;
  final DateTime? wantedTo;
  final String? notes;
  final String status; // waiting | contacted | booked | not_interested
  final String source; // owner | customer

  bool get isOpen => status == 'waiting' || status == 'contacted';
  bool get hasDates => wantedFrom != null && wantedTo != null;

  factory Inquiry.fromJson(Map<String, dynamic> j) => Inquiry(
        id: j['id'],
        clothId: j['cloth_id'],
        clothCode: j['cloth_code'],
        clothName: j['cloth_name'],
        clothImage: j['cloth_image'],
        name: j['name'],
        phone: j['phone'],
        email: j['email'],
        instagram: j['instagram'],
        offeredAmount: _num(j['offered_amount']),
        wantedFrom: _date(j['wanted_from']),
        wantedTo: _date(j['wanted_to']),
        notes: j['notes'],
        status: j['status'],
        source: j['source'],
      );
}

class EarningsRow {
  EarningsRow({required this.label, required this.bookings, required this.rent, required this.collected, required this.depositKept});
  final String label; // "2026-10-18" / "2026-10" for dates, cloth code for clothes
  final int bookings;
  final double rent, collected, depositKept;
  double get income => rent + depositKept;
}

class ClothEarnings extends EarningsRow {
  ClothEarnings({
    required this.clothId,
    required this.clothName,
    this.clothImage,
    required this.daysRented,
    required super.label,
    required super.bookings,
    required super.rent,
    required super.collected,
    required super.depositKept,
  });
  final int clothId;
  final String clothName;
  final String? clothImage;
  final double daysRented;
}

class Earnings {
  Earnings({
    required this.group,
    required this.bookings,
    required this.rentTotal,
    required this.rentCollected,
    required this.rentPending,
    required this.depositKept,
    required this.income,
    required this.depositsHeldNow,
    required this.byDate,
    required this.byCloth,
  });

  final String group; // day | month
  final int bookings;
  final double rentTotal, rentCollected, rentPending, depositKept, income, depositsHeldNow;
  final List<EarningsRow> byDate;
  final List<ClothEarnings> byCloth;

  factory Earnings.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>;
    return Earnings(
      group: j['group'],
      bookings: t['bookings'],
      rentTotal: _num(t['rent_total']),
      rentCollected: _num(t['rent_collected']),
      rentPending: _num(t['rent_pending']),
      depositKept: _num(t['deposit_kept']),
      income: _num(t['income']),
      depositsHeldNow: _num(t['deposits_held_now']),
      byDate: (j['by_date'] as List)
          .map((e) => EarningsRow(
                label: e['period'],
                bookings: e['bookings'],
                rent: _num(e['rent']),
                collected: _num(e['collected']),
                depositKept: _num(e['deposit_kept']),
              ))
          .toList(),
      byCloth: (j['by_cloth'] as List)
          .map((e) => ClothEarnings(
                clothId: e['cloth_id'],
                label: e['cloth_code'],
                clothName: e['cloth_name'],
                clothImage: e['cloth_image'],
                daysRented: _num(e['days_rented']),
                bookings: e['bookings'],
                rent: _num(e['rent']),
                collected: _num(e['collected']),
                depositKept: _num(e['deposit_kept']),
              ))
          .toList(),
    );
  }
}

/// Everyone booked with the same phone (or the same name, without a phone).
class CustomerSummary {
  CustomerSummary.fromJson(Map<String, dynamic> j)
      : key = j['key'],
        name = j['name'],
        phone = j['phone'],
        bookings = j['bookings'],
        lastBookingAt = _date(j['last_booking_at']),
        rentTotal = _num(j['rent_total']),
        rentPaid = _num(j['rent_paid']),
        balanceDue = _num(j['balance_due']),
        depositsHeld = _num(j['deposits_held']),
        depositsReturned = _num(j['deposits_returned']),
        depositsKept = _num(j['deposits_kept']),
        inquiries = j['inquiries'];

  final String key;
  final String name;
  final String? phone;
  final int bookings;
  final DateTime? lastBookingAt;
  final double rentTotal, rentPaid, balanceDue, depositsHeld, depositsReturned, depositsKept;
  final int inquiries;
}

class CustomerDetail extends CustomerSummary {
  CustomerDetail.fromJson(super.j)
      : otherNames = List<String>.from(j['other_names'] as List),
        rentals = (j['rentals'] as List).map((e) => Rental.fromJson(e)).toList(),
        waitlist = (j['waitlist'] as List).map((e) => Inquiry.fromJson(e)).toList(),
        super.fromJson();

  final List<String> otherNames;
  final List<Rental> rentals; // newest first
  final List<Inquiry> waitlist;
}

/// Same rule as the server: by the last 10 phone digits, else by name.
String customerKey(String name, String? phone) {
  var digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 10) digits = digits.substring(digits.length - 10);
  return digits.length >= 6 ? 'p:$digits' : 'n:${name.toLowerCase().trim().split(RegExp(r'\s+')).join(' ')}';
}
