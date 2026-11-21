import 'package:flutter/material.dart';
import '../services/billing_service.dart';

/// Temporary pre-battle blessings activated in the Sacred Temple's Prayer Room
/// that apply for the Cleric's next battle expedition.
enum SacredBlessing {
  vitality(
    id: 'vitality',
    titleKey: 'temple_blessing_vitality_title',
    fallbackTitle: 'Blessing of Vitality',
    descKey: 'temple_blessing_vitality_desc',
    fallbackDesc: 'Start the next battle with +15 bonus temporary HP.',
    icon: Icons.favorite_rounded,
    accentColor: Color(0xFFEF5350),
  ),
  clairvoyance(
    id: 'clairvoyance',
    titleKey: 'temple_blessing_clairvoyance_title',
    fallbackTitle: 'Blessing of Clairvoyance',
    descKey: 'temple_blessing_clairvoyance_desc',
    fallbackDesc:
        "Automatically reveal the enemy's first 3 moves in the next battle.",
    icon: Icons.visibility_rounded,
    accentColor: Color(0xFFAB47BC),
  ),
  harvest(
    id: 'harvest',
    titleKey: 'temple_blessing_harvest_title',
    fallbackTitle: 'Blessing of Harvest',
    descKey: 'temple_blessing_harvest_desc',
    fallbackDesc:
        'Earn 2x Elemental Orbs from defeated enemies during the next battle.',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF66BB6A),
  );

  final String id;
  final String titleKey;
  final String fallbackTitle;
  final String descKey;
  final String fallbackDesc;
  final IconData icon;
  final Color accentColor;

  const SacredBlessing({
    required this.id,
    required this.titleKey,
    required this.fallbackTitle,
    required this.descKey,
    required this.fallbackDesc,
    required this.icon,
    required this.accentColor,
  });

  static SacredBlessing? fromId(String? id) {
    if (id == null) return null;
    final clean = id.trim();
    for (final blessing in SacredBlessing.values) {
      if (blessing.id == clean) return blessing;
    }
    return null;
  }
}

/// Real-money all-element consumable orb bundles sold in the Adoration Room.
enum ConsumableOrbBundle {
  small(
    productId: BillingService.productConsumableSmall,
    titleKey: 'temple_pack_small_title',
    fallbackTitle: 'Blessing Pouch',
    descKey: 'temple_pack_small_desc',
    fallbackDesc: '+500 of all 5 Elemental Orbs',
    amountPerElement: 500,
    icon: Icons.card_giftcard_rounded,
  ),
  medium(
    productId: BillingService.productConsumableMedium,
    titleKey: 'temple_pack_medium_title',
    fallbackTitle: 'Sacred Reliquary',
    descKey: 'temple_pack_medium_desc',
    fallbackDesc: '+2,500 of all 5 Elemental Orbs',
    amountPerElement: 2500,
    icon: Icons.inventory_2_rounded,
  ),
  large(
    productId: BillingService.productConsumableLarge,
    titleKey: 'temple_pack_large_title',
    fallbackTitle: 'Divine Abundance',
    descKey: 'temple_pack_large_desc',
    fallbackDesc: '+10,000 of all 5 Elemental Orbs',
    amountPerElement: 10000,
    icon: Icons.auto_awesome_rounded,
  );

  final String productId;
  final String titleKey;
  final String fallbackTitle;
  final String descKey;
  final String fallbackDesc;
  final int amountPerElement;
  final IconData icon;

  const ConsumableOrbBundle({
    required this.productId,
    required this.titleKey,
    required this.fallbackTitle,
    required this.descKey,
    required this.fallbackDesc,
    required this.amountPerElement,
    required this.icon,
  });
}
