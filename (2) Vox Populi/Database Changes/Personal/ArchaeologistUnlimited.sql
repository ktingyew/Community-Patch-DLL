-- Personal tweak: remove the per-player Archaeologist cap.
-- VP sets this to 3 in Database Changes/Units/UnitChanges.sql; -1 is this column's existing
-- sentinel for "no limit" (same convention used for e.g. National Wonders).
UPDATE UnitClasses SET MaxPlayerInstances = -1 WHERE Type = 'UNITCLASS_ARCHAEOLOGIST';

-- The unit help/Civilopedia text hardcodes "Maximum 3" as a plain string (VP's
-- UnitTextChanges.sql) - it isn't derived from MaxPlayerInstances, so it goes stale
-- without this override. Just drop the cap sentence; everything else stays identical.
UPDATE Language_en_US
SET Text = 'Archaeologists are a special subtype of Worker that are used to excavate Antiquity Sites to either create Landmark improvements or to extract [ICON_ARTIFACT] Artifacts to fill in [ICON_GREAT_WORK] Great Work of Art slots in selected Buildings and Wonders. Archaeologists may work in territory owned by any player. They are consumed once they complete an Archaeological Dig at an Antiquity Site. Archaeologists may not be purchased with [ICON_GOLD] Gold and may only be built in a City with a [COLOR_POSITIVE_TEXT]{TXT_KEY_BUILDING_MUSEUM}[ENDCOLOR].'
WHERE Tag = 'TXT_KEY_UNIT_HELP_ARCHAEOLOGIST';
