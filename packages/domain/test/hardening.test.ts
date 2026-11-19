// G-75 (D-038): the TS reference refuses the same inputs as the Dart engines, beyond the golden vectors.
// Rolling windows refuse an empty or all-missing list and a bad min_count; no engine reports NaN or an
// infinity; a result keeps a frozen copy of its inputs; a missing list is refused instead of throwing.
// Mirrors human_health_os/test/domain/f011_engine_hardening_test.dart.

import { describe, expect, it } from 'vitest';
import {
  NON_FINITE_RESULT,
  addDays,
  assessSafety,
  assessService,
  bmi,
  combineAmounts,
  computeRecipe,
  daysBetween,
  interpretLabResult,
  median,
  ok,
  olsSlope,
  robustZ,
  rollingMean,
  rollingMedian,
  scaleFood,
  trainingVolumeLoad,
  type FoodSnapshot,
  type InteractionRule,
  type LabInterpretationInput,
  type ModelRef,
  type PreventiveInput,
  type ProductConcept,
} from '../src/index.ts';

const fns = { mean: rollingMean, median: rollingMedian } as const;

describe('rolling windows (min_count, empty lists)', () => {
  for (const [name, fn] of Object.entries(fns)) {
    for (const bad of [0, -1, 1.5, Number.NaN, Number.POSITIVE_INFINITY, '3']) {
      it(`${name} refuses min_count ${String(bad)}`, () => {
        const r = fn({ values: [1, 2, 3], window: 3, min_count: bad as never });
        expect(r.status).toBe('INVALID_INPUT');
        expect(r.errorCode).toBe('INVALID_MIN_COUNT');
        expect(r.value).toBeNull();
      });
    }
    it(`${name} refuses an empty list (no NaN)`, () => {
      const r = fn({ values: [], window: 3 });
      expect(r.status).toBe('MISSING_INPUT');
      expect(r.errorCode).toBe('INSUFFICIENT_OBSERVATIONS');
      expect(r.value).toBeNull();
    });
    it(`${name} refuses an empty list even with min_count 1`, () => {
      expect(fn({ values: [], window: 3, min_count: 1 }).errorCode).toBe('INSUFFICIENT_OBSERVATIONS');
    });
    it(`${name} refuses an all-missing list`, () => {
      const r = fn({ values: [null, Number.NaN, null], window: 3 });
      expect(r.errorCode).toBe('INSUFFICIENT_OBSERVATIONS');
      expect(r.value).toBeNull();
    });
    it(`${name} refuses a missing values list instead of throwing`, () => {
      const r = fn({ window: 3 } as never);
      expect(r.status).toBe('MISSING_INPUT');
      expect(r.errorCode).toBe('MISSING_REQUIRED_INPUT');
      expect(r.missingInputs).toEqual(['values']);
    });
    it(`${name} checks the window before min_count`, () => {
      expect(fn({ values: [1], window: 0, min_count: 0 }).errorCode).toBe('INVALID_WINDOW');
    });
    it(`${name} accepts min_count 2 and 2.0 and a null min_count`, () => {
      for (const mc of [2, 2.0, null, undefined]) {
        const r = fn({ values: [1, null, 3], window: 3, min_count: mc as never });
        expect(r.status, String(mc)).toBe('OK');
        expect(r.value).toBe(2);
      }
    });
  }

  it('median of nothing throws, never a value', () => {
    expect(() => median([])).toThrow(RangeError);
  });
});

describe('missing lists are refused, never thrown', () => {
  it('training volume load without sets', () => {
    const r = trainingVolumeLoad({} as never);
    expect(r.status).toBe('MISSING_INPUT');
    expect(r.errorCode).toBe('MISSING_REQUIRED_INPUT');
    expect(r.missingInputs).toEqual(['sets']);
  });
  it('OLS slope without points', () => {
    const r = olsSlope({} as never);
    expect(r.errorCode).toBe('INSUFFICIENT_OBSERVATIONS');
    expect(r.missingInputs).toEqual(['points']);
  });
  it('robust z without series', () => {
    const r = robustZ({ x: 1 } as never);
    expect(r.errorCode).toBe('INSUFFICIENT_OBSERVATIONS');
    expect(r.missingInputs).toEqual(['series']);
  });
});

describe('non-finite results are refused (NON_FINITE_RESULT)', () => {
  it('BMI overflow', () => {
    const r = bmi({ weight_kg: 1e308, height_m: 1e-200 });
    expect(r.status).toBe('INVALID_INPUT');
    expect(r.errorCode).toBe(NON_FINITE_RESULT);
    expect(r.value).toBeNull();
    expect(r.modelId).toBe('DERIVED-BMI-1');
  });

  it('rolling mean overflow', () => {
    const r = rollingMean({ values: [1e308, 1e308], window: 2 });
    expect(r.errorCode).toBe(NON_FINITE_RESULT);
    expect(r.value).toBeNull();
  });

  it('ok never carries NaN', () => {
    const m: ModelRef = { modelId: 'X', version: '1', resultClass: 'EXPERIMENTAL', unit: null };
    const r = ok(m, Number.NaN, {});
    expect(r.status).toBe('INVALID_INPUT');
    expect(r.value).toBeNull();
    expect(r.errorCode).toBe(NON_FINITE_RESULT);
  });

  const food = (nutrients: Record<string, number | null>): FoodSnapshot => ({
    snapshot_id: 'F',
    name: 'synthetic',
    source: 'SYN',
    basis: { amount: 100, unit: 'g' },
    nutrients,
  });

  it('nutrition scaling overflow refuses the whole map', () => {
    const r = scaleFood(food({ protein_g: 1e308, fiber_g: null }), { amount: 1e10, unit: 'g' });
    expect(r.ok).toBe(false);
    expect(r.error).toBe(NON_FINITE_RESULT);
    expect(r.nutrients).toEqual({});
    expect(r.factor).toBeNull();
  });

  it('nutrition scaling with a zero basis is refused, not infinite', () => {
    const f = { ...food({ protein_g: 1 }), basis: { amount: 0, unit: 'g' as const } };
    const r = scaleFood(f, { amount: 10, unit: 'g' });
    expect(r.ok).toBe(false);
    expect(r.error).toBe(NON_FINITE_RESULT);
  });

  it('recipe totals overflow refuses the recipe', () => {
    const ing = { food: food({ protein_g: 1e308 }), quantity: { amount: 100, unit: 'g' } };
    const r = computeRecipe({
      recipe_id: 'R',
      version: 1,
      name: 'overflow',
      ingredients: [ing, ing],
      serving_count: 2,
      final_cooked_mass_g: 100,
    });
    expect(r.ok).toBe(false);
    expect(r.errors.at(-1)).toEqual({ ingredient: 'overflow', error: NON_FINITE_RESULT });
    expect(r.totals).toEqual({});
    expect(r.per_serving).toBeNull();
    expect(r.per_100g_cooked).toBeNull();
  });

  it('lab RCV and baseline overflow', () => {
    const lab = (value: number, observed_at: string) => ({
      analyte_key: 'SYN',
      value,
      unit: 'u',
      observed_at,
      method_id: 'M',
      specimen: 'S',
    });
    const input: LabInterpretationInput = {
      result: lab(1e308, '2026-02-01'),
      reference: [],
      context: {},
      decision_rules: [],
      critical_rules: [],
      prior: lab(1e-308, '2026-01-01'),
      comparability_records: [],
      rcv: { cva: 1, cvi: 1, z: 1.96, source: 'SYN' },
      baseline_points: [-1e-300, 0, 1e-300, 2e-300, 3e-300],
    };
    const a = interpretLabResult(input);
    expect(a.rcv.state).toBe(NON_FINITE_RESULT);
    expect(a.rcv.observed_percent_change).toBeNull();
    expect(a.rcv.rcv_percent).not.toBeNull();
    expect(a.baseline.state).toBe(NON_FINITE_RESULT);
    expect(a.baseline.robust_z).toBeNull();
    expect(a.baseline.n).toBe(5);
  });

  it('lab RCV percent overflow', () => {
    const lab = (value: number) => ({ analyte_key: 'SYN', value, unit: 'u', observed_at: '2026-01-01', method_id: 'M', specimen: 'S' });
    const a = interpretLabResult({
      result: lab(2),
      reference: [],
      context: {},
      decision_rules: [],
      critical_rules: [],
      prior: lab(1),
      comparability_records: [],
      rcv: { cva: 1e200, cvi: 1, z: 1.96, source: 'SYN' },
      baseline_points: [],
    });
    expect(a.rcv).toEqual({ state: NON_FINITE_RESULT, rcv_percent: null, observed_percent_change: null, source: 'SYN' });
  });

  it('medication amounts that overflow are not combined', () => {
    const same = combineAmounts([
      { amount: 1e308, unit: 'g', basis: 'AS_LABELED' },
      { amount: 1e308, unit: 'g', basis: 'AS_LABELED' },
    ]);
    expect(same).toEqual({ value: null, unit: null, reason: NON_FINITE_RESULT });
    const mixed = combineAmounts([
      { amount: 1e308, unit: 'g', basis: 'AS_LABELED' },
      { amount: 1, unit: 'mg', basis: 'AS_LABELED' },
    ]);
    expect(mixed).toEqual({ value: null, unit: null, reason: NON_FINITE_RESULT });
  });
});

describe('inputs are a frozen copy', () => {
  it('mutating the caller object after compute changes nothing', () => {
    const inputs = { values: [1, 2, 3] as Array<number | null>, window: 3 };
    const r = rollingMean(inputs);
    inputs.window = 99;
    inputs.values.push(1000);
    expect(r.inputs.window).toBe(3);
    expect(r.inputs.values).toEqual([1, 2, 3]);
    expect(Object.isFrozen(r.inputs)).toBe(true);
    expect(Object.isFrozen(r.inputs.values)).toBe(true);
    expect(() => {
      (r.inputs as Record<string, unknown>).window = 1;
    }).toThrow(TypeError);
    expect(() => (r.inputs.values as number[]).push(4)).toThrow(TypeError);
  });

  it('a refusal also keeps a copy', () => {
    const inputs: { weight_kg: number | null; height_m: number } = { weight_kg: null, height_m: 1.8 };
    const r = bmi(inputs);
    inputs.weight_kg = 80;
    expect(r.inputs.weight_kg).toBeNull();
    expect(r.missingInputs).toEqual(['weight_kg']);
  });

  it('nested objects are copied too', () => {
    const sets = [{ load_kg: 50, reps: 10, state: 'COMPLETED' as const }];
    const r = trainingVolumeLoad({ sets });
    sets[0]!.reps = 1;
    expect((r.inputs.sets as Array<{ reps: number }>)[0]!.reps).toBe(10);
    expect(r.value).toBe(500);
  });
});

// F011-S3: the two remaining groups of the Dart hardening test, for the behaviour TS shares. The Dart
// assessments also carry missingInputs (and preventive limitations); those are Dart-only additions to the
// TS shape (see the headers of medication_safety.dart and preventive.dart), so they are not asserted here.
describe('medication safety wording', () => {
  const pack = { pack_id: 'P', version: '1', status: 'SYNTHETIC' };
  it('no rule found is never a guarantee of safety', () => {
    const a = assessSafety([], [{ entry_id: 'E', product_id: 'NOT-IN-CATALOGUE', kind: 'TAKEN', servings_per_day: 1, time: null }], [], [], pack);
    expect(a.findings).toHaveLength(1);
    expect(a.findings[0]!.type).toBe('CLEAR_NO_MATCH_FOUND');
    expect(a.findings[0]!.guaranteed_safe).toBe(false);
    expect(a.findings[0]!.note).toContain('NOT a guarantee of safety');
    expect(a.limitations.join(' ')).toContain('No rule found ≠ guaranteed safe');
    expect(a.limitations.join(' ')).toContain('never prescribes');
  });

  it('a timing rule without an intake time asks for context', () => {
    const product = (id: string, ing: string): ProductConcept => ({
      product_id: id,
      name: id.toLowerCase(),
      route: 'ORAL',
      label_version: 'L1',
      composition_known: true,
      ingredients: [{ ingredient_id: ing, label: ing.toLowerCase(), amount: 1, unit: 'mg', basis: 'AS_LABELED', mapping: 'REVIEWED' }],
    });
    const rule: InteractionRule = {
      rule_id: 'T',
      version: '1',
      source: 'SYN',
      kind: 'TIMING_SEPARATION',
      participants: ['I1', 'I2'],
      route: null,
      min_separation_minutes: 120,
      action: 'SEPARATE_TIMING',
      test_only: true,
    };
    const a = assessSafety(
      [product('A', 'I1'), product('B', 'I2')],
      [
        { entry_id: 'E1', product_id: 'A', kind: 'PLAN', servings_per_day: 1, time: '08:00' },
        { entry_id: 'E2', product_id: 'B', kind: 'PLAN', servings_per_day: 1, time: null },
      ],
      [rule],
      [],
      pack,
    );
    expect(a.findings).toHaveLength(1);
    expect(a.findings[0]!.type).toBe('INSUFFICIENT_CONTEXT');
    expect(a.findings[0]!.combined_reason).toBe('MISSING_TIME');
    expect(a.findings[0]!.action).toBeNull();
  });

  it('mass units combine into the largest unit; IU never converts', () => {
    const okSum = combineAmounts([
      { amount: 500, unit: 'mcg', basis: 'AS_LABELED' },
      { amount: 1, unit: 'mg', basis: 'AS_LABELED' },
    ]);
    expect(okSum.value).toBe(1.5);
    expect(okSum.unit).toBe('mg');
    const iu = combineAmounts([
      { amount: 400, unit: 'IU', basis: 'AS_LABELED' },
      { amount: 1, unit: 'mg', basis: 'AS_LABELED' },
    ]);
    expect(iu.value).toBeNull();
    expect(iu.reason).toBe('UNIT_CONVERSION_RULE_NOT_INSTALLED');
    const undisclosed = combineAmounts([
      { amount: null, unit: 'mg', basis: 'AS_LABELED' },
      { amount: 1, unit: 'mg', basis: 'AS_LABELED' },
    ]);
    expect(undisclosed.reason).toBe('UNDISCLOSED_AMOUNT');
  });
});

describe('preventive engine', () => {
  const input: PreventiveInput = {
    as_of: '2026-10-06',
    jurisdiction: null,
    age_years: null,
    risks: [],
    anatomy: [],
    history: 'UNKNOWN',
    completions: [],
    contraindicated: false,
    due_soon_window_days: 30,
  };
  it('no active pack is reported, never assumed', () => {
    const a = assessService('SVC', [], input);
    expect(a.assessment_status).toBe('NO_ACTIVE_PACK');
    expect(a.next_due_date).toBeNull();
    expect(a.recommendation_mode).toBeNull();
  });

  it('calendar arithmetic is timezone-free and leap-aware', () => {
    expect(addDays('2026-03-01', 730)).toBe('2028-02-29');
    expect(daysBetween('2026-10-06', '2026-10-20')).toBe(14);
    expect(addDays('2026-12-31T23:59:59Z', 1)).toBe('2027-01-01');
  });
});
