// Display-side domain rules. Mirrors apps/ios/WantWiseCore (Countdown.swift, Want.swift, WantSections.swift).
// Both sides are tested against docs/fixtures/countdown-cases.json so they can't drift.

export type SourceType = "manual" | "screenshot" | "photo" | "sharedURL" | "sharedText";
export type WantStatus = "captured" | "waiting" | "stillWant" | "purchased" | "noLongerWant";
export type WantPhase =
  | "needsReflection"
  | "waiting"
  | "readyToReconsider"
  | "stillWant"
  | "purchased"
  | "noLongerWant";

/** Display-safe projection of a Want. Deliberately excludes private notes, parent data and deletion state. */
export interface DisplayWant {
  id: string;
  title: string;
  imageUrl: string | null;
  sourceType: SourceType;
  priceMinor: number | null;
  /** ISO 4217. Always explicit per Want. */
  currency: string;
  reason: string | null;
  status: WantStatus;
  createdAt: string;
  revisitAt: string | null;
  waitStartedAt: string | null;
  decidedAt: string | null;
}

export interface DisplaySnapshot {
  child: { displayName: string };
  /** IANA zone the household lives in; countdowns use its calendar days. */
  timeZone: string;
  wants: DisplayWant[];
  generatedAt: string;
}

// ---------- Calendar days in a time zone ----------

const ymdFormatters = new Map<string, Intl.DateTimeFormat>();

function ymdParts(instant: Date, timeZone: string): { y: number; m: number; d: number } {
  let fmt = ymdFormatters.get(timeZone);
  if (!fmt) {
    fmt = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" });
    ymdFormatters.set(timeZone, fmt);
  }
  const parts = Object.fromEntries(fmt.formatToParts(instant).map((p) => [p.type, p.value]));
  return { y: Number(parts.year), m: Number(parts.month), d: Number(parts.day) };
}

/** Whole local calendar days from start's day to end's day (DST-safe). */
export function calendarDaysBetween(start: Date, end: Date, timeZone: string): number {
  const a = ymdParts(start, timeZone);
  const b = ymdParts(end, timeZone);
  return Math.round((Date.UTC(b.y, b.m - 1, b.d) - Date.UTC(a.y, a.m - 1, a.d)) / 86_400_000);
}

/** Offset (ms) of a zone from UTC at a given instant. */
function zoneOffsetMs(instant: Date, timeZone: string): number {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const p = Object.fromEntries(fmt.formatToParts(instant).map((x) => [x.type, x.value]));
  const asUTC = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUTC - Math.floor(instant.getTime() / 1000) * 1000;
}

/** The instant of a local wall-clock time in a zone. */
export function zonedInstant(y: number, m: number, d: number, hour: number, minute: number, timeZone: string): Date {
  const guess = Date.UTC(y, m - 1, d, hour, minute);
  let instant = guess - zoneOffsetMs(new Date(guess), timeZone);
  // Second pass corrects for an offset change between the guess and the answer (DST boundaries).
  instant = guess - zoneOffsetMs(new Date(instant), timeZone);
  return new Date(instant);
}

/** Same rule as RevisitPolicy.revisitDate(afterDays:): the local day `days` from now, at 4 pm. */
export function revisitAfterDays(days: number, now: Date, timeZone: string, hour = 16): Date {
  const { y, m, d } = ymdParts(now, timeZone);
  const target = new Date(Date.UTC(y, m - 1, d + days));
  return zonedInstant(target.getUTCFullYear(), target.getUTCMonth() + 1, target.getUTCDate(), hour, 0, timeZone);
}

// ---------- Countdown ----------

export type Countdown =
  | { kind: "ready"; text: string }
  | { kind: "today"; text: string }
  | { kind: "tomorrow"; text: string }
  | { kind: "days"; days: number; text: string };

export function countdownUntil(revisitAt: Date, now: Date, timeZone: string): Countdown {
  if (revisitAt.getTime() <= now.getTime()) return { kind: "ready", text: "Ready to think again" };
  const days = calendarDaysBetween(now, revisitAt, timeZone);
  if (days <= 0) return { kind: "today", text: "Reconsider today" };
  if (days === 1) return { kind: "tomorrow", text: "Reconsider tomorrow" };
  return { kind: "days", days, text: `${days} days left` };
}

export function agoText(createdAt: Date, now: Date, timeZone: string): string {
  const days = calendarDaysBetween(createdAt, now, timeZone);
  if (days <= 0) return "earlier today";
  if (days === 1) return "yesterday";
  return `${days} days ago`;
}

// ---------- Want helpers ----------

export function phaseOf(want: DisplayWant, now: Date): WantPhase {
  switch (want.status) {
    case "captured":
      return "needsReflection";
    case "waiting":
      return want.revisitAt && new Date(want.revisitAt).getTime() <= now.getTime() ? "readyToReconsider" : "waiting";
    default:
      return want.status;
  }
}

/** Fraction of the current waiting period that has passed, 0..1; null when not waiting. */
export function waitProgress(want: DisplayWant, now: Date): number | null {
  if (want.status !== "waiting" || !want.revisitAt) return null;
  const start = new Date(want.waitStartedAt ?? want.createdAt).getTime();
  const total = new Date(want.revisitAt).getTime() - start;
  if (total <= 0) return 1;
  return Math.min(1, Math.max(0, (now.getTime() - start) / total));
}

/** Short status line for a card. */
export function statusText(want: DisplayWant, now: Date, timeZone: string): string {
  switch (phaseOf(want, now)) {
    case "needsReflection":
      return "Just added";
    case "waiting":
    case "readyToReconsider":
      return countdownUntil(new Date(want.revisitAt!), now, timeZone).text;
    case "stillWant":
      return "Still wants it";
    case "purchased":
      return "Bought";
    case "noLongerWant":
      return "Decided to pass";
  }
}

const zeroDecimal = new Set(["JPY", "KRW", "VND", "CLP", "ISK"]);

/** "$49" for whole amounts, "$12.99" otherwise. Always uses the Want's own currency. */
export function formatPrice(priceMinor: number | null, currency: string, locale = "en-CA"): string | null {
  if (priceMinor == null) return null;
  const digits = zeroDecimal.has(currency.toUpperCase()) ? 0 : 2;
  const value = priceMinor / 10 ** digits;
  const whole = Number.isInteger(value);
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency,
    currencyDisplay: "narrowSymbol",
    minimumFractionDigits: whole ? 0 : digits,
    maximumFractionDigits: digits,
  }).format(value);
}

/**
 * Order for the "Thinking About" scene: ready first (oldest revisit first), then waiting (soonest first),
 * then just-captured (newest first). Decided Wants belong to a later "Recent decisions" scene.
 */
export function thinkingAbout(wants: DisplayWant[], now: Date): DisplayWant[] {
  const t = (s: string | null) => (s ? new Date(s).getTime() : 0);
  const ready = wants.filter((w) => phaseOf(w, now) === "readyToReconsider").sort((a, b) => t(a.revisitAt) - t(b.revisitAt));
  const waiting = wants.filter((w) => phaseOf(w, now) === "waiting").sort((a, b) => t(a.revisitAt) - t(b.revisitAt));
  const captured = wants.filter((w) => w.status === "captured").sort((a, b) => t(b.createdAt) - t(a.createdAt));
  return [...ready, ...waiting, ...captured];
}
