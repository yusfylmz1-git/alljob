import 'package:flutter/material.dart';

import 'app_image.dart';

/// İlan görseli — fotoğraf varsa fotoğraf, YOKSA meslek ikonu + renk.
///
/// İlanların çoğu fotoğrafsız açılıyor, yani ikonlu hâl istisna değil
/// VARSAYILAN görünüm. Boş gri kutu yerine kategoriyi anlatan renkli bir
/// rozet gösteriyoruz: liste renkli kalır ve kullanıcı ilanın ne işi
/// olduğunu okumadan anlar.
///
/// Renk/ikon MESLEK GRUBUNA bağlıdır ([_visualFor]) — 130 meslek için tek tek
/// ikon tanımlamak bakımsız olurdu; yeni bir meslek eklendiğinde grup ön ekine
/// düşer, düşmezse nötr yapı ikonuna iner.
class JobThumb extends StatelessWidget {
  const JobThumb({
    super.key,
    required this.photos,
    required this.category,
    this.size = 56,
    this.radius = 12,
  });

  /// `Job.photos` — ilk fotoğraf kullanılır.
  final List<String> photos;

  /// `Job.category` — meslek kodu (`kProfessionNames` anahtarı).
  final String category;

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(radius);

    // Boş dizeler fotoğraf sayılmaz: eski kayıtlarda '' gelebiliyor ve
    // AppImage boş handle'da kırık görsel gösterirdi.
    final photo = photos.where((p) => p.trim().isNotEmpty).firstOrNull;

    if (photo != null) {
      return ClipRRect(
        borderRadius: border,
        child: SizedBox(
          width: size,
          height: size,
          child: AppImage(
            handle: photo,
            fit: BoxFit.cover,
            memCacheWidth: (size * 3).round(),
          ),
        ),
      );
    }

    final visual = _visualFor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: border,
        color: visual.color.withValues(alpha: 0.13),
      ),
      alignment: Alignment.center,
      child: Icon(visual.icon, size: size * 0.46, color: visual.color),
    );
  }
}

/// Bir meslek grubunun görsel kimliği.
class JobVisual {
  const JobVisual(this.icon, this.color);
  final IconData icon;
  final Color color;
}

/// Meslek kodu → ikon + renk.
///
/// Önce TAM eşleşme, sonra grup ön eki denenir; hiçbiri tutmazsa nötr yapı
/// ikonu döner. Renkler birbirinden ayrışsın diye sınırlı bir paletten
/// seçildi — liste kalabalıklaştığında gökkuşağı etkisi olmasın.
JobVisual jobVisualFor(String category) => _visualFor(category);

JobVisual _visualFor(String category) {
  final c = category.trim().toLowerCase();

  const su = Color(0xFF0EA5E9); // mavi — su/tesisat
  const elektrik = Color(0xFFF59E0B); // amber — elektrik/enerji
  const ahsap = Color(0xFF92400E); // kahve — ahşap/mobilya
  const boya = Color(0xFF8B5CF6); // mor — boya/dekorasyon
  const yapi = Color(0xFF64748B); // gri — kaba yapı
  const arac = Color(0xFFEF4444); // kırmızı — araç
  const temizlik = Color(0xFF10B981); // yeşil — temizlik/bahçe
  const teknoloji = Color(0xFF3B82F6); // mavi — elektronik
  const kisisel = Color(0xFFEC4899); // pembe — kişisel bakım
  const ofis = Color(0xFF6366F1); // indigo — danışmanlık
  const acil = Color(0xFFF97316); // turuncu — hemen lazım

  const exact = <String, JobVisual>{
    // ── Su / tesisat ──
    'plumber': JobVisual(Icons.plumbing_rounded, su),
    'drain': JobVisual(Icons.water_damage_rounded, su),
    'leak_detect': JobVisual(Icons.water_damage_rounded, su),
    'water_heater': JobVisual(Icons.hot_tub_rounded, su),
    'water_softener': JobVisual(Icons.opacity_rounded, su),
    'boiler': JobVisual(Icons.local_fire_department_rounded, su),
    'natural_gas': JobVisual(Icons.gas_meter_rounded, su),
    'septic': JobVisual(Icons.water_rounded, su),
    'well': JobVisual(Icons.water_rounded, su),
    'irrigation': JobVisual(Icons.water_drop_rounded, temizlik),
    'pool': JobVisual(Icons.pool_rounded, su),
    'sauna': JobVisual(Icons.hot_tub_rounded, su),
    'waterproofing': JobVisual(Icons.umbrella_rounded, su),

    // ── Elektrik / enerji ──
    'electrician': JobVisual(Icons.electrical_services_rounded, elektrik),
    'power_line': JobVisual(Icons.electrical_services_rounded, elektrik),
    'chandelier': JobVisual(Icons.light_rounded, elektrik),
    'solar': JobVisual(Icons.solar_power_rounded, elektrik),
    'generator': JobVisual(Icons.bolt_rounded, elektrik),
    'generator_install': JobVisual(Icons.bolt_rounded, elektrik),
    'ups': JobVisual(Icons.battery_charging_full_rounded, elektrik),
    'lightning': JobVisual(Icons.flash_on_rounded, elektrik),
    'ac_technician': JobVisual(Icons.ac_unit_rounded, su),
    'elevator': JobVisual(Icons.elevator_rounded, yapi),

    // ── Ahşap / mobilya ──
    'carpenter': JobVisual(Icons.carpenter_rounded, ahsap),
    'furniture_assembly': JobVisual(Icons.chair_rounded, ahsap),
    'kitchen_cabinet': JobVisual(Icons.kitchen_rounded, ahsap),
    'wardrobe': JobVisual(Icons.door_sliding_rounded, ahsap),
    'parquet': JobVisual(Icons.grid_on_rounded, ahsap),
    'upholstery': JobVisual(Icons.weekend_rounded, ahsap),
    'fence_wood': JobVisual(Icons.fence_rounded, ahsap),

    // ── Boya / dekorasyon ──
    'painter': JobVisual(Icons.format_paint_rounded, boya),
    'painter_deco': JobVisual(Icons.format_paint_rounded, boya),
    'wallpaper': JobVisual(Icons.wallpaper_rounded, boya),
    'epoxy': JobVisual(Icons.layers_rounded, boya),
    'curtain': JobVisual(Icons.curtains_rounded, boya),
    'curtain_rail': JobVisual(Icons.curtains_rounded, boya),
    'blind': JobVisual(Icons.blinds_rounded, boya),
    'plasterer': JobVisual(Icons.roller_shades_rounded, boya),

    // ── Kaba yapı ──
    'tiler': JobVisual(Icons.grid_view_rounded, yapi),
    'mason': JobVisual(Icons.foundation_rounded, yapi),
    'concrete': JobVisual(Icons.foundation_rounded, yapi),
    'reinforcement': JobVisual(Icons.construction_rounded, yapi),
    'formwork': JobVisual(Icons.construction_rounded, yapi),
    'roofer': JobVisual(Icons.roofing_rounded, yapi),
    'insulation': JobVisual(Icons.thermostat_rounded, yapi),
    'marble': JobVisual(Icons.square_foot_rounded, yapi),
    'stone': JobVisual(Icons.terrain_rounded, yapi),
    'excavation': JobVisual(Icons.agriculture_rounded, yapi),
    'demolition': JobVisual(Icons.construction_rounded, yapi),
    'scaffolding': JobVisual(Icons.stairs_rounded, yapi),
    'crane': JobVisual(Icons.precision_manufacturing_rounded, yapi),
    'paving': JobVisual(Icons.grid_on_rounded, yapi),
    'asphalt': JobVisual(Icons.add_road_rounded, yapi),
    'chimney': JobVisual(Icons.holiday_village_rounded, yapi),

    // ── Doğrama / cam / kapı ──
    'glass': JobVisual(Icons.window_rounded, teknoloji),
    'aluminum': JobVisual(Icons.window_rounded, yapi),
    'pvc_window': JobVisual(Icons.window_rounded, yapi),
    'steel_door': JobVisual(Icons.door_front_door_rounded, yapi),
    'shutter': JobVisual(Icons.blinds_closed_rounded, yapi),
    'awning': JobVisual(Icons.deck_rounded, temizlik),
    'ironwork': JobVisual(Icons.fence_rounded, yapi),
    'locksmith': JobVisual(Icons.vpn_key_rounded, elektrik),
    'key_copy': JobVisual(Icons.key_rounded, elektrik),

    // ── Metal / imalat ──
    'welder': JobVisual(Icons.local_fire_department_rounded, arac),
    'welding_tig': JobVisual(Icons.local_fire_department_rounded, arac),
    'welding_mobile': JobVisual(Icons.local_fire_department_rounded, arac),
    'cnc': JobVisual(Icons.precision_manufacturing_rounded, yapi),
    'lathe': JobVisual(Icons.precision_manufacturing_rounded, yapi),
    'blacksmith': JobVisual(Icons.hardware_rounded, yapi),

    // ── Araç ──
    'auto_mechanic': JobVisual(Icons.car_repair_rounded, arac),
    'auto_electric': JobVisual(Icons.car_repair_rounded, arac),
    'auto_body': JobVisual(Icons.directions_car_rounded, arac),
    'auto_glass': JobVisual(Icons.directions_car_rounded, arac),
    'auto_detail': JobVisual(Icons.local_car_wash_rounded, arac),
    'tire': JobVisual(Icons.tire_repair_rounded, arac),
    'battery': JobVisual(Icons.battery_charging_full_rounded, arac),
    'towing': JobVisual(Icons.car_crash_rounded, arac),
    'motorcycle': JobVisual(Icons.two_wheeler_rounded, arac),
    'bike': JobVisual(Icons.pedal_bike_rounded, arac),
    'boat': JobVisual(Icons.sailing_rounded, su),
    'agricultural': JobVisual(Icons.agriculture_rounded, temizlik),

    // ── Temizlik / bahçe / taşıma ──
    'cleaner': JobVisual(Icons.cleaning_services_rounded, temizlik),
    'carpet_wash': JobVisual(Icons.dry_cleaning_rounded, temizlik),
    'pest_control': JobVisual(Icons.pest_control_rounded, temizlik),
    'gardener': JobVisual(Icons.yard_rounded, temizlik),
    'mover': JobVisual(Icons.local_shipping_rounded, acil),
    'courier': JobVisual(Icons.delivery_dining_rounded, acil),
    'driving': JobVisual(Icons.airport_shuttle_rounded, acil),

    // ── Elektronik / teknoloji ──
    'white_goods': JobVisual(Icons.local_laundry_service_rounded, teknoloji),
    'appliance_install': JobVisual(Icons.kitchen_rounded, teknoloji),
    'phone_repair': JobVisual(Icons.smartphone_rounded, teknoloji),
    'computer': JobVisual(Icons.computer_rounded, teknoloji),
    'tv_repair': JobVisual(Icons.tv_rounded, teknoloji),
    'printer': JobVisual(Icons.print_rounded, teknoloji),
    'network': JobVisual(Icons.settings_ethernet_rounded, teknoloji),
    'smart_home': JobVisual(Icons.home_rounded, teknoloji),
    'security_cam': JobVisual(Icons.videocam_rounded, teknoloji),
    'satellite': JobVisual(Icons.satellite_alt_rounded, teknoloji),
    'sewing_machine': JobVisual(Icons.settings_rounded, teknoloji),
    'fire_safety': JobVisual(Icons.fire_extinguisher_rounded, arac),

    // ── Kişisel bakım / sağlık ──
    'barber': JobVisual(Icons.content_cut_rounded, kisisel),
    'hairdresser': JobVisual(Icons.content_cut_rounded, kisisel),
    'makeup': JobVisual(Icons.face_retouching_natural_rounded, kisisel),
    'nail': JobVisual(Icons.back_hand_rounded, kisisel),
    'massage': JobVisual(Icons.spa_rounded, kisisel),
    'physiotherapy': JobVisual(Icons.healing_rounded, kisisel),
    'nurse_home': JobVisual(Icons.medical_services_rounded, kisisel),
    'babysitter': JobVisual(Icons.child_care_rounded, kisisel),
    'elder_care': JobVisual(Icons.elderly_rounded, kisisel),

    // ── Evcil hayvan ──
    'pet_grooming': JobVisual(Icons.pets_rounded, kisisel),
    'vet_visit': JobVisual(Icons.pets_rounded, temizlik),
    'dog_walker': JobVisual(Icons.pets_rounded, temizlik),

    // ── Eğitim / etkinlik / medya ──
    'tutor': JobVisual(Icons.menu_book_rounded, ofis),
    'language': JobVisual(Icons.translate_rounded, ofis),
    'music_teacher': JobVisual(Icons.music_note_rounded, ofis),
    'photographer': JobVisual(Icons.photo_camera_rounded, ofis),
    'videographer': JobVisual(Icons.videocam_rounded, ofis),
    'dj': JobVisual(Icons.speaker_rounded, ofis),
    'event': JobVisual(Icons.celebration_rounded, kisisel),
    'catering': JobVisual(Icons.restaurant_rounded, kisisel),
    'waiter_event': JobVisual(Icons.room_service_rounded, kisisel),
    'signage': JobVisual(Icons.storefront_rounded, ofis),
    'printing': JobVisual(Icons.print_rounded, ofis),

    // ── Ofis / danışmanlık ──
    'lawyer_consult': JobVisual(Icons.gavel_rounded, ofis),
    'accountant': JobVisual(Icons.calculate_rounded, ofis),
    'real_estate': JobVisual(Icons.apartment_rounded, ofis),
    'insurance': JobVisual(Icons.shield_rounded, ofis),
    'translation': JobVisual(Icons.translate_rounded, ofis),
    'notary_assist': JobVisual(Icons.description_rounded, ofis),
    'sewing': JobVisual(Icons.checkroom_rounded, kisisel),
    'shoe_repair': JobVisual(Icons.hiking_rounded, ahsap),

    // ── Hemen Lazım ──
    'quick_support': JobVisual(Icons.bolt_rounded, acil),
    'other': JobVisual(Icons.bolt_rounded, acil),
  };

  final hit = exact[c];
  if (hit != null) return hit;

  // Tam eşleşme yoksa ön ekten grubu tahmin et: professions.json'a yeni bir
  // 'auto_*' / 'water_*' eklendiğinde kod değişmeden doğru gruba düşsün.
  const prefixes = <String, JobVisual>{
    'auto_': JobVisual(Icons.directions_car_rounded, arac),
    'water_': JobVisual(Icons.water_drop_rounded, su),
    'welding_': JobVisual(Icons.local_fire_department_rounded, arac),
    'painter_': JobVisual(Icons.format_paint_rounded, boya),
    'generator_': JobVisual(Icons.bolt_rounded, elektrik),
    'curtain_': JobVisual(Icons.curtains_rounded, boya),
  };
  for (final e in prefixes.entries) {
    if (c.startsWith(e.key)) return e.value;
  }

  // Bilinmeyen kod: nötr ama "iş" hissi veren yapı ikonu.
  return const JobVisual(Icons.handyman_rounded, yapi);
}
