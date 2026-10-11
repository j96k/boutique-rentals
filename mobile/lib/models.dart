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
    required this.advancePaid,
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
  final double advancePaid;
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
        advancePaid: _num(j['advance_paid']),
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
  });

  final int total, available, onRent, overdue;
  final List<Rental> goingOutToday, returningToday, overdueList;

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
