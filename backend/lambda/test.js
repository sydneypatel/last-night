// --- paste the 3 functions first ---
function getOffsetMs(timeZone, date) {
  var dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    hour12: false,
  });
  var map = {};
  dtf.formatToParts(date).forEach(function(p) { map[p.type] = p.value; });
  if (map.hour === '24') map.hour = '00';
  var asUTC = Date.UTC(+map.year, +map.month - 1, +map.day, +map.hour, +map.minute, +map.second);
  return asUTC - date.getTime();
}

function zonedWallClockToUtc(year, month, day, hour, minute, timeZone) {
  var guess = Date.UTC(year, month - 1, day, hour, minute, 0);
  var offset = getOffsetMs(timeZone, new Date(guess));
  return new Date(guess - offset);
}

function getNextSunriseInTimezone(timezone) {
  var dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour12: false,
  });
  var map = {};
  dtf.formatToParts(new Date()).forEach(function(p) { map[p.type] = p.value; });
  var base = new Date(Date.UTC(+map.year, +map.month - 1, +map.day));
  base.setUTCDate(base.getUTCDate() + 1);
  return zonedWallClockToUtc(
    base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(),
    6, 30, timezone
  );
}

// --- then the test ---
const timezones = [
  'America/New_York',
  'America/Los_Angeles',
  'America/Chicago',
  'Europe/London',
  'Asia/Tokyo',
];

timezones.forEach(tz => {
  const result = getNextSunriseInTimezone(tz);
  console.log(`${tz}: ${result.toISOString()} (local = ${result.toLocaleString('en-US', { timeZone: tz })})`);
});