-- A short note on each dungeon and raid for its Overview: why it exists and
-- why adventurers go there. Written by hand (not generated); places new in
-- WoW: Forever (or changed there, like Hyjal Summit) have none until their
-- story is known. Each note is a phrase in Locales/enUS.lua, translated
-- like the rest of NeedRoll's text.
local _, ns = ...
local L = ns.L

ns.Data.lore = {
    RAGEFIRE = L["A network of volcanic caves running beneath Orgrimmar. Troggs and the Searing Blade, a cult of Burning Legion worshippers, have taken root under the Horde's capital, and the Warchief wants them rooted out."],
    WAILING_CAVERNS = L["Caves in the Barrens named for the moaning winds that blow through them. The night elf druid Naralex sought to heal the land here, but his Emerald Dream vision turned into a nightmare that twisted his own disciples into the Druids of the Fang."],
    DEADMINES = L["Once a gold mine under Moonbrook, now the hidden base of the Defias Brotherhood. Edwin VanCleef's stonemasons, cheated of their pay after rebuilding Stormwind, are building a juggernaut here to take their revenge."],
    SHADOWFANG = L["The keep of the mad archmage Arugal above Pyrewood Village. His summoned worgen overran Silverpine Forest, and the Forsaken and the Kirin Tor both want him stopped."],
    BLACKFATHOM = L["A sunken night elf temple once sacred to the moon goddess Elune, on the Ashenvale coast. The Twilight's Hammer and the naga now gather there to wake the ancient creature Aku'mai."],
    STOCKADE = L["Stormwind's prison. The inmates, led by Bazil Thredd and the Defias, have risen up and taken it over, and the city guard needs help putting the riot down."],
    GNOMEREGAN = L["The gnomes' capital beneath Dun Morogh. When troggs invaded, the gnomes flooded it with radiation to drive them out, and the traitor Mekgineer Thermaplugg still holds the irradiated ruins."],
    RAZORFEN_KRAUL = L["A maze of giant thorn vines in the southern Barrens, home of the quilboar. Charlga Razorflank and her followers draw power from the slain demigod Agamaggan's blood."],
    SM_GRAVEYARD = L["The burial grounds behind the Scarlet Crusade's Tirisfal stronghold. The fanatics' own dead have risen here, and the Forsaken want the Crusade's hold on the region broken."],
    SM_LIBRARY = L["The Scarlet Monastery's library, where the Crusade keeps its lore and the relics it seized. Its scholars guard tomes and artifacts that both factions want back."],
    SM_ARMORY = L["The Scarlet Monastery's training grounds and armory, overseen by Herod, the Scarlet champion who drills the Crusade's soldiers."],
    SM_CATHEDRAL = L["The heart of the Scarlet Monastery, held by High Inquisitor Whitemane and Scarlet Commander Mograine, who lead the Crusade's zealous war on the undead."],
    RAZORFEN_DOWNS = L["The quilboar's ancestral burial grounds in the Barrens. The Scourge has corrupted them, and the lich Amnennar the Coldbringer has turned the quilboar dead to his service."],
    ULDAMAN = L["An excavation in the Badlands uncovering a titan vault. The dwarves of the Explorers' League race the Dark Iron dwarves and troggs to unearth the Discs of Norgannon and the truth of the dwarves' stone origins."],
    ZULFARRAK = L["A Sandfury troll city in the deserts of Tanaris. Its priests command the dead and plan to wake the hydra Gahz'rilla, and treasure hunters and Horde and Alliance agents all want a piece of it."],
    MARAUDON = L["A sacred cave in Desolace where the centaur's progenitor Zaetar is buried. Princess Theradras, his elemental consort, has corrupted the waters, and the Cenarion Circle wants the land healed."],
    SUNKEN_TEMPLE = L["The Temple of Atal'Hakkar, sunk into the Swamp of Sorrows by the green dragonflight to stop the Atal'ai trolls from summoning their blood god Hakkar. The Atal'ai are trying again."],
    BRD = L["The Dark Iron dwarves' capital inside Blackrock Mountain, ruled by Emperor Dagran Thaurissan in the service of Ragnaros. Princess Moira Bronzebeard of Ironforge is held here, and her fate draws both factions in."],
    LBRS = L["The lower halls of the fortress atop Blackrock Mountain, held by the Blackrock orcs of the Dark Horde. Warchief Rend Blackhand gathers his forces here."],
    UBRS = L["The upper spire of Blackrock, where General Drakkisath of the black dragonflight commands the Dark Horde. Those who would face Nefarian in Blackwing Lair must earn their way past him."],
    DM_EAST = L["The eastern wing of Eldre'Thalas, an ancient Highborne city in Feralas. Satyrs and corrupted ancients haunt its gardens, drawing power from the demon Immol'thar's prison."],
    DM_WEST = L["The western wing of Dire Maul, where the last Highborne of Eldre'Thalas keep the demon Immol'thar imprisoned to feed their magic, and Prince Tortheldrin holds court."],
    DM_NORTH = L["The northern wing of Dire Maul, taken over by the Gordok ogres. Their king, King Gordok, can be overthrown, and the ogres will crown whoever does it."],
    SCHOLOMANCE = L["The school of necromancy in the crypts beneath Caer Darrow, run by the Cult of the Damned. Darkmaster Gandling and his faculty train the Scourge's necromancers here."],
    STRAT_LIVE = L["The fallen city of Stratholme, where Arthas purged the plagued citizens. The Scarlet Crusade still holds its living half under Grand Crusader Dathrohan, who is not what he seems."],
    STRAT_UNDEAD = L["The Scourge-held half of Stratholme, ruled by Baron Rivendare, Death Knight of the Lich King. His ziggurats feed the plague that still grips the Eastern Plaguelands."],

    -- Raids
    MOLTEN_CORE = L["The fiery heart of Blackrock Mountain, where the Dark Iron dwarves' summoning brought the Firelord Ragnaros back into the world. His lieutenants guard the depths, and the Hydraxian Waterlords want the Firelord sent back."],
    ONYXIA = L["A cave in the Dustwallow Marsh where Onyxia, daughter of Deathwing, rests between her schemes. Disguised as Lady Katrana Prestor, she has been steering Stormwind's court, and her lair holds the proof of who she is."],
    BWL = L["Nefarian's laboratory atop Blackrock Spire. The son of Deathwing breeds chromatic dragons there from the blood of every dragonflight, hoping to build an army no one can stand against."],
    ZULGURUB = L["The Gurubashi trolls' capital in Stranglethorn Vale. The Atal'ai priests have brought the blood god Hakkar the Soulflayer into the world here, and the Zandalari tribe has called on outsiders to stop him."],
    AQ20 = L["The ruins outside the walls of Ahn'Qiraj in Silithus. General Rajaxx and Ossirian the Unscarred lead the qiraji armies here, and the Cenarion Circle asks for help pushing them back."],
    AQ40 = L["The temple city of Ahn'Qiraj, where the silithid and qiraji serve the Old God C'Thun. The Scarab Wall that held them for a thousand years has been opened, and the god's servants must be stopped at its heart."],
    NAXXRAMAS = L["A floating necropolis over the Eastern Plaguelands, seat of the lich Kel'Thuzad. From here the Scourge plans its next assault, and the Argent Dawn is preparing a strike against it."],
}

function ns.Data:Lore(instanceID)
    return self.lore[instanceID]
end
