export const RANKED_TIMEZONE = 'Asia/Kolkata';
const istMonth = new Intl.DateTimeFormat('en-CA', { timeZone: RANKED_TIMEZONE, year: 'numeric', month: '2-digit' });

export interface SeasonInterval { id: string; timezone: typeof RANKED_TIMEZONE; startsAt: Date; endsAt: Date }

function validInstant(instant: Date): void {
  if (!(instant instanceof Date) || !Number.isFinite(instant.getTime())) throw new RangeError('Invalid trusted instant.');
}

export function seasonIdAt(instant: Date): string {
  validInstant(instant);
  const parts = istMonth.formatToParts(instant);
  const year = parts.find(p => p.type === 'year')!.value.padStart(4, '0');
  const month = parts.find(p => p.type === 'month')!.value;
  const id = `${year}-${month}`;
  seasonBounds(id); // Enforce the same supported calendar range as explicit lookup.
  return id;
}

export function seasonBounds(id: string): SeasonInterval {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(id)) throw new RangeError('Invalid season ID.');
  const year = Number(id.slice(0, 4));
  const month = Number(id.slice(5));
  // Modern IST has a fixed +05:30 offset. Intl supplies the IANA calendar identity;
  // explicit offset dates construct UTC instants without consulting the host timezone.
  if (year < 1970 || year > 9998) throw new RangeError('Unsupported ranked season year.');
  const nextYear = month === 12 ? year + 1 : year;
  const nextMonth = month === 12 ? 1 : month + 1;
  return {
    id, timezone: RANKED_TIMEZONE,
    startsAt: new Date(`${id}-01T00:00:00.000+05:30`),
    endsAt: new Date(`${nextYear}-${String(nextMonth).padStart(2, '0')}-01T00:00:00.000+05:30`),
  };
}

export function seasonAt(instant: Date): SeasonInterval { return seasonBounds(seasonIdAt(instant)); }

export function isInSeason(instant: Date, season: SeasonInterval): boolean {
  validInstant(instant);
  return instant.getTime() >= season.startsAt.getTime() && instant.getTime() < season.endsAt.getTime();
}
