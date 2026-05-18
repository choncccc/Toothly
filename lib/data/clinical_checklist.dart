/// Checklist items per clinic level.
///
/// REPLACE the placeholder items below with the real clinical cases for each
/// level. Keep `key` stable per item — it's used as the storage path and the
/// row identifier in Supabase, so renaming a key will orphan prior uploads.
class ChecklistItem {
  final String key;
  final String title;
  final String? subtitle;
  final String? section;

  const ChecklistItem({
    required this.key,
    required this.title,
    this.subtitle,
    this.section,
  });
}

class ClinicalChecklist {
  ClinicalChecklist._();

  /// Canonical level labels — must match what register_view.dart writes to
  /// `profiles.year` and what `clinical_case_items.level` stores.
  static const List<String> levels = [
    'Level I',
    'Level II',
    'Level III',
  ];

  static const Map<String, List<ChecklistItem>> byLevel = {
    'Level I': _levelOne,
    'Level II': _levelTwo,
    'Level III': _levelThree,
  };

  static List<ChecklistItem> itemsFor(String level) =>
      byLevel[level] ?? const [];

  // ---------------------------------------------------------------------------
  // LEVEL I — Clinical Dentistry 1: Comprehensive Patient Case Management
  // ---------------------------------------------------------------------------
  static const List<ChecklistItem> _levelOne = [
    // Removable Partial Denture Case (1)
    ChecklistItem(
      key: 'l1_rpd_case_1',
      title: 'Removable Partial Denture #1',
      section: 'Removable Partial Denture Case',
      subtitle: 'Removable Partial Denture Case',
    ),

    // Periodontology Department Patient Cases (5)
    ChecklistItem(
      key: 'l1_perio_mild_1',
      title: 'Mild Case #1',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Mild',
    ),
    ChecklistItem(
      key: 'l1_perio_mild_2',
      title: 'Mild Case #2',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Mild',
    ),
    ChecklistItem(
      key: 'l1_perio_moderate_1',
      title: 'Moderate Case #1',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Moderate',
    ),
    ChecklistItem(
      key: 'l1_perio_moderate_2',
      title: 'Moderate Case #2',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Moderate',
    ),
    ChecklistItem(
      key: 'l1_perio_stage1_grade_a_1',
      title: 'Perio Case (≥ Periodontitis Stage 1 Grade A)',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Periodontitis',
    ),

    // Restorative Dentistry Patient Cases (9)
    ChecklistItem(
      key: 'l1_resto_class1_patient_1',
      title: 'Class 1 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l1_resto_class1_patient_2',
      title: 'Class 1 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l1_resto_class1_patient_3',
      title: 'Class 1 Patient Case #3',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l1_resto_class1_patient_4',
      title: 'Class 1 Patient Case #4',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l1_resto_class1_patient_5',
      title: 'Class 1 Patient Case #5',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l1_resto_class3_patient_1',
      title: 'Class 3 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l1_resto_class3_patient_2',
      title: 'Class 3 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l1_resto_class3_patient_3',
      title: 'Class 3 Patient Case #3',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l1_resto_class3_patient_4',
      title: 'Class 3 Patient Case #4',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),

    // Complete Denture Case (1)
    ChecklistItem(
      key: 'l1_cd_case_1',
      title: 'Complete Denture #1',
      section: 'Complete Denture Case',
      subtitle: 'Complete Denture Case',
    ),

    // Surgery Patient Cases (7)
    ChecklistItem(
      key: 'l1_surgery_extraction_1',
      title: 'Simple Tooth Extraction #1',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),
    ChecklistItem(
      key: 'l1_surgery_extraction_2',
      title: 'Simple Tooth Extraction #2',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),
    ChecklistItem(
      key: 'l1_surgery_extraction_3',
      title: 'Simple Tooth Extraction #3',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),
    ChecklistItem(
      key: 'l1_surgery_extraction_4',
      title: 'Simple Tooth Extraction #4',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),
    ChecklistItem(
      key: 'l1_surgery_extraction_5',
      title: 'Simple Tooth Extraction #5',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),
    ChecklistItem(
      key: 'l1_surgery_extraction_6',
      title: 'Simple Tooth Extraction #6',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),
    ChecklistItem(
      key: 'l1_surgery_extraction_7',
      title: 'Simple Tooth Extraction #7',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Simple Extraction',
    ),

    // Restorative Dentistry Simulated Cases — Typhodont (42)
    // Class 1 (6 unfilled + 6 filled)
    ChecklistItem(
      key: 'l1_resto_sim_class1_unfilled_1',
      title: 'Class 1 Typhodont (Unfilled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_unfilled_2',
      title: 'Class 1 Typhodont (Unfilled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_unfilled_3',
      title: 'Class 1 Typhodont (Unfilled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_unfilled_4',
      title: 'Class 1 Typhodont (Unfilled) #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_unfilled_5',
      title: 'Class 1 Typhodont (Unfilled) #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_unfilled_6',
      title: 'Class 1 Typhodont (Unfilled) #6',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_filled_1',
      title: 'Class 1 Typhodont (Filled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_filled_2',
      title: 'Class 1 Typhodont (Filled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_filled_3',
      title: 'Class 1 Typhodont (Filled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_filled_4',
      title: 'Class 1 Typhodont (Filled) #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_filled_5',
      title: 'Class 1 Typhodont (Filled) #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class1_filled_6',
      title: 'Class 1 Typhodont (Filled) #6',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 1 · Filled',
    ),
    // Class 2 (6 unfilled + 6 filled)
    ChecklistItem(
      key: 'l1_resto_sim_class2_unfilled_1',
      title: 'Class 2 Typhodont (Unfilled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_unfilled_2',
      title: 'Class 2 Typhodont (Unfilled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_unfilled_3',
      title: 'Class 2 Typhodont (Unfilled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_unfilled_4',
      title: 'Class 2 Typhodont (Unfilled) #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_unfilled_5',
      title: 'Class 2 Typhodont (Unfilled) #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_unfilled_6',
      title: 'Class 2 Typhodont (Unfilled) #6',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_filled_1',
      title: 'Class 2 Typhodont (Filled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_filled_2',
      title: 'Class 2 Typhodont (Filled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_filled_3',
      title: 'Class 2 Typhodont (Filled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_filled_4',
      title: 'Class 2 Typhodont (Filled) #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_filled_5',
      title: 'Class 2 Typhodont (Filled) #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class2_filled_6',
      title: 'Class 2 Typhodont (Filled) #6',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 2 · Filled',
    ),
    // Class 3 (3 unfilled + 3 filled)
    ChecklistItem(
      key: 'l1_resto_sim_class3_unfilled_1',
      title: 'Class 3 Typhodont (Unfilled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 3 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class3_unfilled_2',
      title: 'Class 3 Typhodont (Unfilled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 3 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class3_unfilled_3',
      title: 'Class 3 Typhodont (Unfilled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 3 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class3_filled_1',
      title: 'Class 3 Typhodont (Filled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 3 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class3_filled_2',
      title: 'Class 3 Typhodont (Filled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 3 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class3_filled_3',
      title: 'Class 3 Typhodont (Filled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 3 · Filled',
    ),
    // Class 4 (3 unfilled + 3 filled)
    ChecklistItem(
      key: 'l1_resto_sim_class4_unfilled_1',
      title: 'Class 4 Typhodont (Unfilled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 4 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class4_unfilled_2',
      title: 'Class 4 Typhodont (Unfilled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 4 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class4_unfilled_3',
      title: 'Class 4 Typhodont (Unfilled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 4 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class4_filled_1',
      title: 'Class 4 Typhodont (Filled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 4 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class4_filled_2',
      title: 'Class 4 Typhodont (Filled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 4 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class4_filled_3',
      title: 'Class 4 Typhodont (Filled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 4 · Filled',
    ),
    // Class 5 (3 unfilled + 3 filled)
    ChecklistItem(
      key: 'l1_resto_sim_class5_unfilled_1',
      title: 'Class 5 Typhodont (Unfilled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 5 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class5_unfilled_2',
      title: 'Class 5 Typhodont (Unfilled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 5 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class5_unfilled_3',
      title: 'Class 5 Typhodont (Unfilled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 5 · Unfilled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class5_filled_1',
      title: 'Class 5 Typhodont (Filled) #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 5 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class5_filled_2',
      title: 'Class 5 Typhodont (Filled) #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 5 · Filled',
    ),
    ChecklistItem(
      key: 'l1_resto_sim_class5_filled_3',
      title: 'Class 5 Typhodont (Filled) #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Typhodont · Class 5 · Filled',
    ),

    // Prosthodontics Simulated Cases (5)
    ChecklistItem(
      key: 'l1_prostho_sim_rpd_design_1',
      title: 'RPD Exercise — Board Type Cast (Upper/Lower Designing) #1',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho · RPD Designing · 5-hr activity',
    ),
    ChecklistItem(
      key: 'l1_prostho_sim_rpd_design_2',
      title: 'RPD Exercise — Board Type Cast (Upper/Lower Designing) #2',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho · RPD Designing · 5-hr activity',
    ),
    ChecklistItem(
      key: 'l1_prostho_sim_cd_exercise_1',
      title: 'Complete Denture Exercise (1-day, Magnetic Articulator)',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho · CD · 8AM–12PM, 1PM–6PM',
    ),
    ChecklistItem(
      key: 'l1_prostho_sim_anterior_crown_1',
      title: 'Fixed Restoration — Anterior Crown',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho · Fixed · Anterior crown',
    ),
    ChecklistItem(
      key: 'l1_prostho_sim_anterior_fpd_1',
      title: 'Fixed Restoration — Anterior FPD (Mx Central Incisor & Canine)',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho · Fixed · 5-hr activity',
    ),

    // Endodontics Simulated Case (1)
    ChecklistItem(
      key: 'l1_endo_sim_anterior_1',
      title: 'Endodontics Exercise — Anterior Tooth Specimen',
      section: 'Endodontics Simulated Case',
      subtitle: 'Endo · X-ray capable, mounted in endo jaw',
    ),
  ];

  // ---------------------------------------------------------------------------
  // LEVEL II — Clinic 2: Comprehensive Patient Case Management
  // ---------------------------------------------------------------------------
  static const List<ChecklistItem> _levelTwo = [
    // Comprehensive Patient Case Management (2)
    ChecklistItem(
      key: 'l2_comprehensive_rpd_1',
      title: 'Removable Partial Denture Case',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · RPD',
    ),
    ChecklistItem(
      key: 'l2_comprehensive_perio_stage2_grade_b_1',
      title: 'Periodontal Treatment Case (≥ Periodontitis Stage II Grade B)',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Periodontal',
    ),

    // Periodontology — Oral Prophylaxis (5)
    ChecklistItem(
      key: 'l2_perio_op_moderate_1',
      title: 'Oral Prophylaxis — Moderate #1',
      section: 'Periodontology — Oral Prophylaxis',
      subtitle: 'Perio · Moderate',
    ),
    ChecklistItem(
      key: 'l2_perio_op_moderate_2',
      title: 'Oral Prophylaxis — Moderate #2',
      section: 'Periodontology — Oral Prophylaxis',
      subtitle: 'Perio · Moderate',
    ),
    ChecklistItem(
      key: 'l2_perio_op_moderate_3',
      title: 'Oral Prophylaxis — Moderate #3',
      section: 'Periodontology — Oral Prophylaxis',
      subtitle: 'Perio · Moderate',
    ),
    ChecklistItem(
      key: 'l2_perio_op_moderate_4',
      title: 'Oral Prophylaxis — Moderate #4',
      section: 'Periodontology — Oral Prophylaxis',
      subtitle: 'Perio · Moderate',
    ),
    ChecklistItem(
      key: 'l2_perio_op_severe_1',
      title: 'Oral Prophylaxis — Severe #1',
      section: 'Periodontology — Oral Prophylaxis',
      subtitle: 'Perio · Severe',
    ),

    // Restorative Dentistry Patient Cases (11)
    ChecklistItem(
      key: 'l2_resto_class1_patient_1',
      title: 'Class 1 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_class1_patient_2',
      title: 'Class 1 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_class1_patient_3',
      title: 'Class 1 Patient Case #3',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_class2_patient_1',
      title: 'Class 2 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_class2_patient_2',
      title: 'Class 2 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_class3_patient_1',
      title: 'Class 3 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l2_resto_class3_patient_2',
      title: 'Class 3 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l2_resto_class4_patient_1',
      title: 'Class 4 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 4',
    ),
    ChecklistItem(
      key: 'l2_resto_class4_patient_2',
      title: 'Class 4 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 4',
    ),
    ChecklistItem(
      key: 'l2_resto_class5_patient_1',
      title: 'Class 5 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 5',
    ),
    ChecklistItem(
      key: 'l2_resto_class5_patient_2',
      title: 'Class 5 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 5',
    ),

    // Endodontic Patient Case (1)
    ChecklistItem(
      key: 'l2_endo_monorooted_1',
      title: 'Endodontic Case — Monorooted',
      section: 'Endodontic Patient Case',
      subtitle: 'Endo · Monorooted',
    ),

    // Pediatric Patient Case (3)
    ChecklistItem(
      key: 'l2_pedia_oral_prophylaxis_1',
      title: 'Pediatric — Oral Prophylaxis',
      section: 'Pediatric Patient Case',
      subtitle: 'Pedia · Oral Prophylaxis',
    ),
    ChecklistItem(
      key: 'l2_pedia_pfs_1',
      title: 'Pediatric — Pit and Fissure Sealant',
      section: 'Pediatric Patient Case',
      subtitle: 'Pedia · PFS',
    ),
    ChecklistItem(
      key: 'l2_pedia_simple_restoration_1',
      title: 'Pediatric — Simple Restoration',
      section: 'Pediatric Patient Case',
      subtitle: 'Pedia · Simple Restoration',
    ),

    // Prosthodontics Patient Cases (3)
    ChecklistItem(
      key: 'l2_prostho_cd_ideal_1',
      title: 'Complete Denture — Ideal Mx/Md Arch (no pre-prosthetic surgery)',
      section: 'Prosthodontics Patient Cases',
      subtitle: 'Prostho · Complete Denture',
    ),
    ChecklistItem(
      key: 'l2_prostho_fixed_posterior_crown_1',
      title: 'Fixed Restoration — Posterior Crown',
      section: 'Prosthodontics Patient Cases',
      subtitle: 'Prostho · Fixed · Posterior crown',
    ),
    ChecklistItem(
      key: 'l2_prostho_fixed_anterior_fpd_1',
      title: 'Fixed Restoration — Anterior FPD',
      section: 'Prosthodontics Patient Cases',
      subtitle: 'Prostho · Fixed · Anterior FPD',
    ),

    // Surgery Patient Cases (16)
    ChecklistItem(
      key: 'l2_surgery_monorooted_1',
      title: 'Monorooted Extraction #1',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_monorooted_2',
      title: 'Monorooted Extraction #2',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_monorooted_3',
      title: 'Monorooted Extraction #3',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_monorooted_4',
      title: 'Monorooted Extraction #4',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_monorooted_5',
      title: 'Monorooted Extraction #5',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_1',
      title: 'Multirooted Extraction #1',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_2',
      title: 'Multirooted Extraction #2',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_3',
      title: 'Multirooted Extraction #3',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_4',
      title: 'Multirooted Extraction #4',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_5',
      title: 'Multirooted Extraction #5',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_6',
      title: 'Multirooted Extraction #6',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_7',
      title: 'Multirooted Extraction #7',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_8',
      title: 'Multirooted Extraction #8',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_9',
      title: 'Multirooted Extraction #9',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_multirooted_10',
      title: 'Multirooted Extraction #10',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l2_surgery_open_1',
      title: 'Open Surgery',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Open',
    ),

    // Restorative Dentistry Simulated Cases (21)
    ChecklistItem(
      key: 'l2_resto_sim_class1_1',
      title: 'Class 1 Simulated #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class1_2',
      title: 'Class 1 Simulated #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class1_3',
      title: 'Class 1 Simulated #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class1_4',
      title: 'Class 1 Simulated #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class1_5',
      title: 'Class 1 Simulated #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class1_6',
      title: 'Class 1 Simulated #6',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class2_1',
      title: 'Class 2 Simulated #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class2_2',
      title: 'Class 2 Simulated #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class2_3',
      title: 'Class 2 Simulated #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class2_4',
      title: 'Class 2 Simulated #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class2_5',
      title: 'Class 2 Simulated #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class2_6',
      title: 'Class 2 Simulated #6',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class3_1',
      title: 'Class 3 Simulated #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 3',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class3_2',
      title: 'Class 3 Simulated #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 3',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class3_3',
      title: 'Class 3 Simulated #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 3',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class4_1',
      title: 'Class 4 Simulated #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 4',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class4_2',
      title: 'Class 4 Simulated #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 4',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class4_3',
      title: 'Class 4 Simulated #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 4',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class5_1',
      title: 'Class 5 Simulated #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 5',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class5_2',
      title: 'Class 5 Simulated #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 5',
    ),
    ChecklistItem(
      key: 'l2_resto_sim_class5_3',
      title: 'Class 5 Simulated #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 5',
    ),

    // Prosthodontics Simulated Cases (5)
    ChecklistItem(
      key: 'l2_prostho_sim_rpd_design_1',
      title: 'RPD Designing — 1 pair Upper/Lower #1',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · RPD designing',
    ),
    ChecklistItem(
      key: 'l2_prostho_sim_rpd_design_2',
      title: 'RPD Designing — 1 pair Upper/Lower #2',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · RPD designing',
    ),
    ChecklistItem(
      key: 'l2_prostho_sim_cd_exercise_1',
      title: 'Complete Denture Exercise (1-day, Semi-adjustable Articulator)',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · CD · 8AM–12PM, 1PM–6PM',
    ),
    ChecklistItem(
      key: 'l2_prostho_sim_anterior_crown_1',
      title: 'Fixed Restoration — Anterior Crown',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · Fixed · Anterior crown',
    ),
    ChecklistItem(
      key: 'l2_prostho_sim_antero_posterior_fpd_1',
      title: 'Fixed Restoration — Antero-Posterior FPD (Mx canine & 2nd premolar)',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · Fixed · A-P FPD',
    ),
  ];

  // ---------------------------------------------------------------------------
  // LEVEL III — Clinic 3
  // ---------------------------------------------------------------------------
  static const List<ChecklistItem> _levelThree = [
    // Comprehensive Patient Case Management (6)
    ChecklistItem(
      key: 'l3_comprehensive_multirooted_endo_1',
      title: 'Multirooted Endodontic Case',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Endo · Multirooted',
    ),
    ChecklistItem(
      key: 'l3_comprehensive_surgical_perio_stage3_grade_b_1',
      title: 'Surgical Periodontal Treatment (≥ Stage III Grade B)',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Surgical Periodontal',
    ),
    ChecklistItem(
      key: 'l3_comprehensive_posterior_fpd_1',
      title: 'Posterior Fixed Partial Denture Case',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Posterior FPD',
    ),
    ChecklistItem(
      key: 'l3_comprehensive_pedia_crown_1',
      title: 'Pediatric Case — Crown Restoration',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Pedia · Crown',
    ),
    ChecklistItem(
      key: 'l3_comprehensive_pedia_pulp_therapy_1',
      title: 'Pediatric Case — Pulp Therapy',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Pedia · Pulp Therapy',
    ),
    ChecklistItem(
      key: 'l3_comprehensive_pedia_space_maintainer_1',
      title: 'Pediatric Case — Space Maintainer/Regainer',
      section: 'Comprehensive Patient Case Management',
      subtitle: 'Comprehensive · Pedia · Space Maintainer/Regainer',
    ),

    // Periodontology Department Patient Cases (4)
    ChecklistItem(
      key: 'l3_perio_moderate_1',
      title: 'Moderate Case #1',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Moderate',
    ),
    ChecklistItem(
      key: 'l3_perio_moderate_2',
      title: 'Moderate Case #2',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Moderate',
    ),
    ChecklistItem(
      key: 'l3_perio_moderate_3',
      title: 'Moderate Case #3',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Moderate',
    ),
    ChecklistItem(
      key: 'l3_perio_severe_1',
      title: 'Severe Case #1',
      section: 'Periodontology Department Patient Cases',
      subtitle: 'Periodontology · Severe',
    ),

    // Restorative Dentistry Patient Cases (11)
    ChecklistItem(
      key: 'l3_resto_class1_patient_1',
      title: 'Class 1 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_class1_patient_2',
      title: 'Class 1 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_class1_patient_3',
      title: 'Class 1 Patient Case #3',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_class2_patient_1',
      title: 'Class 2 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 2',
    ),
    ChecklistItem(
      key: 'l3_resto_class2_patient_2',
      title: 'Class 2 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 2',
    ),
    ChecklistItem(
      key: 'l3_resto_class3_patient_1',
      title: 'Class 3 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l3_resto_class3_patient_2',
      title: 'Class 3 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 3',
    ),
    ChecklistItem(
      key: 'l3_resto_class4_patient_1',
      title: 'Class 4 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 4',
    ),
    ChecklistItem(
      key: 'l3_resto_class4_patient_2',
      title: 'Class 4 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 4',
    ),
    ChecklistItem(
      key: 'l3_resto_class5_patient_1',
      title: 'Class 5 Patient Case #1',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 5',
    ),
    ChecklistItem(
      key: 'l3_resto_class5_patient_2',
      title: 'Class 5 Patient Case #2',
      section: 'Restorative Dentistry Patient Cases',
      subtitle: 'Restorative · Class 5',
    ),

    // Prosthodontics Patient Cases (1)
    ChecklistItem(
      key: 'l3_prostho_cd_pre_prosthetic_1',
      title: 'Complete Denture (Requiring Pre-Prosthetic Surgery)',
      section: 'Prosthodontics Patient Cases',
      subtitle: 'Prostho · Complete Denture',
    ),

    // Pediatric Patient Cases (4)
    ChecklistItem(
      key: 'l3_pedia_prr_1',
      title: 'Preventive Resin Restoration',
      section: 'Pediatric Patient Cases',
      subtitle: 'Pedia · PRR',
    ),
    ChecklistItem(
      key: 'l3_pedia_sdf_gic_1',
      title: 'SDF with GIC Restoration',
      section: 'Pediatric Patient Cases',
      subtitle: 'Pedia · SDF + GIC',
    ),
    ChecklistItem(
      key: 'l3_pedia_pfs_permanent_1',
      title: 'Pit and Fissure Sealant (Permanent Tooth)',
      section: 'Pediatric Patient Cases',
      subtitle: 'Pedia · PFS · Permanent',
    ),
    ChecklistItem(
      key: 'l3_pedia_fluoride_1',
      title: 'Fluoride Application',
      section: 'Pediatric Patient Cases',
      subtitle: 'Pedia · Fluoride',
    ),

    // Surgery Patient Cases (11)
    ChecklistItem(
      key: 'l3_surgery_monorooted_1',
      title: 'Monorooted Extraction #1',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_monorooted_2',
      title: 'Monorooted Extraction #2',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Monorooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_pedia_1',
      title: 'Pediatric Extraction #1',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Pediatric',
    ),
    ChecklistItem(
      key: 'l3_surgery_pedia_2',
      title: 'Pediatric Extraction #2',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Pediatric',
    ),
    ChecklistItem(
      key: 'l3_surgery_pedia_3',
      title: 'Pediatric Extraction #3',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Pediatric',
    ),
    ChecklistItem(
      key: 'l3_surgery_multirooted_1',
      title: 'Multirooted Extraction #1',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_multirooted_2',
      title: 'Multirooted Extraction #2',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_multirooted_3',
      title: 'Multirooted Extraction #3',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_multirooted_4',
      title: 'Multirooted Extraction #4',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_multirooted_5',
      title: 'Multirooted Extraction #5',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Multirooted',
    ),
    ChecklistItem(
      key: 'l3_surgery_pre_prosthetic_1',
      title: 'Pre-Prosthetic Surgery',
      section: 'Surgery Patient Cases',
      subtitle: 'Surgery · Pre-Prosthetic',
    ),

    // Restorative Dentistry Simulated Cases (10)
    ChecklistItem(
      key: 'l3_resto_sim_class1_1',
      title: 'Class 1 Typodont #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class1_2',
      title: 'Class 1 Typodont #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class1_3',
      title: 'Class 1 Typodont #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class1_4',
      title: 'Class 1 Typodont #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class1_5',
      title: 'Class 1 Typodont #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 1',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class2_1',
      title: 'Class 2 Typodont #1',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class2_2',
      title: 'Class 2 Typodont #2',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class2_3',
      title: 'Class 2 Typodont #3',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class2_4',
      title: 'Class 2 Typodont #4',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),
    ChecklistItem(
      key: 'l3_resto_sim_class2_5',
      title: 'Class 2 Typodont #5',
      section: 'Restorative Dentistry Simulated Cases',
      subtitle: 'Resto Sim · Class 2',
    ),

    // Prosthodontics Simulated Cases (5)
    ChecklistItem(
      key: 'l3_prostho_sim_rpd_design_1',
      title: 'RPD Designing — 1 pair Upper/Lower #1',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · RPD designing · 3-hr activity',
    ),
    ChecklistItem(
      key: 'l3_prostho_sim_rpd_design_2',
      title: 'RPD Designing — 1 pair Upper/Lower #2',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · RPD designing · 3-hr activity',
    ),
    ChecklistItem(
      key: 'l3_prostho_sim_cd_exercise_1',
      title: 'Complete Denture Exercise',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · CD',
    ),
    ChecklistItem(
      key: 'l3_prostho_sim_posterior_crown_1',
      title: 'Fixed Restoration — Posterior Crown',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · Fixed · Posterior crown',
    ),
    ChecklistItem(
      key: 'l3_prostho_sim_posterior_fpd_1',
      title: 'Fixed Restoration — Posterior FPD (Mx 2nd Premolar & 2nd Molar)',
      section: 'Prosthodontics Simulated Cases',
      subtitle: 'Prostho Sim · Fixed · Posterior FPD',
    ),
  ];
}
