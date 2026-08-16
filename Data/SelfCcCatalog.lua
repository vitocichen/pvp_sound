---@type string, Addon
local _, addon = ...

-- Debuffs on player/teammates. Primary Id for UI; Ids = all aura variants to register.
addon.Data.SelfCcCatalog = {
	Classes = {
		{
			Key = "General",
			Name = "General",
			Spells = {
				{ Id = 107079, File = "quakingPalm.ogg", Name = "Quaking Palm", Ids = { [107079] = true } },
				{ Id = 11876, File = "warStomp.ogg", Name = "War Stomp", Ids = { [11876] = true, [15593] = true, [16727] = true, [20549] = true, [24375] = true, [27758] = true, [28725] = true, [31408] = true, [31480] = true, [31755] = true, [36835] = true, [38911] = true, [40936] = true, [41534] = true, [46026] = true, [56427] = true, [59705] = true, [60960] = true, [61065] = true, [69613] = true, [71019] = true, [74606] = true, [81500] = true, [129831] = true, [166969] = true, [170794] = true, [185492] = true, [189504] = true, [195546] = true, [196907] = true, [204717] = true, [204747] = true, [223440] = true, [239164] = true, [241287] = true, [241863] = true, [244200] = true, [262539] = true, [294895] = true, [314723] = true, [384336] = true, [404736] = true } },
			},
		},
		{
			Key = "DeathKnight",
			Name = "Death Knight",
			Spells = {
				{ Id = 93422, File = "asphyxiate.ogg", Name = "Asphyxiate", Ids = { [93422] = true, [108194] = true, [221562] = true, [285266] = true } },
				{ Id = 47476, File = "Strangulate.ogg", Name = "Strangulate", Ids = { [47476] = true, [51131] = true, [55314] = true, [55334] = true, [66018] = true } },
				{ Id = 91800, File = "Smash.ogg", Name = "Gnaw", Ids = { [91800] = true, [91797] = true, [212332] = true, [212337] = true } },
				{ Id = 91802, File = "ShamblingRush.ogg", Name = "Shambling Rush", Ids = { [91802] = true } },
				{ Id = 77606, File = "darksimulacrum.ogg", Name = "Dark Simulacrum", Ids = { [77606] = true } },
				{ Id = 207167, File = "blindingSleet.ogg", Name = "Blinding Sleet", Ids = { [207167] = true } },
			},
		},
		{
			Key = "DemonHunter",
			Name = "Demon Hunter",
			Spells = {
				{ Id = 217832, File = "imprison.ogg", Name = "Imprison", Ids = { [217832] = true, [221527] = true, [332544] = true, [386761] = true, [1217930] = true, [1233620] = true } },
				{ Id = 179057, File = "chaosNova.ogg", Name = "Chaos Nova", Ids = { [179057] = true, [190246] = true, [199828] = true, [222826] = true, [292224] = true } },
				{ Id = 207685, File = "fearSigil.ogg", Name = "Sigil of Misery", Ids = { [207685] = true } },
				{ Id = 207771, File = "Sinfulbrand.ogg", Name = "Fiery Brand", Ids = { [207771] = true } },
			},
		},
		{
			Key = "Druid",
			Name = "Druid",
			Spells = {
				{ Id = 33786, File = "Cyclone.ogg", Name = "Cyclone", Ids = { [33786] = true, [39594] = true, [40578] = true, [43528] = true, [60236] = true, [61662] = true, [65859] = true, [88010] = true, [160209] = true, [261521] = true, [268341] = true, [373248] = true, [410870] = true, [427556] = true } },
				{ Id = 5211, File = "mightyBash.ogg", Name = "Mighty Bash", Ids = { [5211] = true, [166972] = true } },
				{ Id = 99, File = "disorientingRoar.ogg", Name = "Incapacitating Roar", Ids = { [99] = true } },
				{ Id = 339, File = "entanglingRoots.ogg", Name = "Entangling Roots", Ids = { [339] = true, [11922] = true, [12747] = true, [20654] = true, [20699] = true, [21331] = true, [22127] = true, [22415] = true, [22800] = true, [24648] = true, [26071] = true, [31287] = true, [32173] = true, [33844] = true, [37823] = true, [40363] = true, [57095] = true, [65857] = true, [66070] = true, [66967] = true, [96633] = true, [105143] = true, [132743] = true, [149065] = true, [170855] = true, [173089] = true, [177606] = true, [186456] = true, [196216] = true, [201192] = true, [201589] = true, [235963] = true, [247564] = true, [272681] = true, [278176] = true, [288581] = true, [311634] = true, [311761] = true, [330873] = true, [358232] = true, [371453] = true, [373249] = true, [384648] = true, [393384] = true, [414942] = true, [425573] = true, [460614] = true, [1227880] = true, [1247716] = true, [1271297] = true, [1287975] = true } },
				{ Id = 203123, File = "maim.ogg", Name = "Maim", Ids = { [203123] = true, [203126] = true, [214429] = true } },
				{ Id = 2637, File = "hibernate.ogg", Name = "Hibernate", Ids = { [2637] = true, [84868] = true, [201431] = true, [390406] = true } },
				{ Id = 81261, File = "SolarBeam.ogg", Name = "Solar Beam", Ids = { [81261] = true, [129889] = true, [1264226] = true } },
				{ Id = 102359, File = "massEntanglement.ogg", Name = "Mass Entanglement", Ids = { [102359] = true, [424497] = true } },
				{ Id = 163505, File = "rakeStun.ogg", Name = "Rake", Ids = { [163505] = true } },
			},
		},
		{
			Key = "Evoker",
			Name = "Evoker",
			Spells = {
				{ Id = 360806, File = "sleepWalk.ogg", Name = "Sleep Walk", Ids = { [360806] = true } },
				{ Id = 355689, File = "landslide.ogg", Name = "Landslide", Ids = { [355689] = true, [21808] = true, [398345] = true, [414257] = true } },
			},
		},
		{
			Key = "Hunter",
			Name = "Hunter",
			Spells = {
				{ Id = 3355, File = "FreezingTrap.ogg", Name = "Freezing Trap", Ids = { [3355] = true, [43415] = true, [43448] = true, [55041] = true, [153574] = true, [173866] = true, [203337] = true, [204460] = true, [240574] = true, [278468] = true, [1215920] = true, [1219266] = true, [1243741] = true, [1271225] = true } },
				{ Id = 19386, File = "WyvernSting.ogg", Name = "Wyvern Sting", Ids = { [19386] = true, [24335] = true, [26180] = true, [41186] = true, [65877] = true, [90488] = true, [258219] = true, [260457] = true, [262000] = true } },
				{ Id = 24394, File = "intimidation.ogg", Name = "Intimidation", Ids = { [24394] = true, [7093] = true, [120558] = true, [123646] = true, [284379] = true, [1258508] = true } },
				{ Id = 23601, File = "scatterShot.ogg", Name = "Scatter Shot", Ids = { [23601] = true, [36732] = true, [46681] = true, [50733] = true, [115199] = true, [162748] = true, [213691] = true, [264942] = true } },
				{ Id = 357021, File = "concussion.ogg", Name = "Consecutive Concussion", Ids = { [357021] = true } },
				{ Id = 356727, File = "spiderSting.ogg", Name = "Spider Sting", Ids = { [356727] = true } },
			},
		},
		{
			Key = "Mage",
			Name = "Mage",
			Spells = {
				{ Id = 118, File = "Polymorph.ogg", Name = "Polymorph", Ids = { [118] = true, [13323] = true, [14621] = true, [15534] = true, [27760] = true, [28271] = true, [28272] = true, [29124] = true, [29848] = true, [30838] = true, [34639] = true, [36840] = true, [38245] = true, [38896] = true, [41334] = true, [43309] = true, [46280] = true, [47731] = true, [58537] = true, [61025] = true, [61305] = true, [61721] = true, [61780] = true, [65801] = true, [66043] = true, [71319] = true, [76826] = true, [126819] = true, [161353] = true, [161354] = true, [161355] = true, [161372] = true, [173098] = true, [218434] = true, [219393] = true, [219394] = true, [219398] = true, [219399] = true, [219400] = true, [219401] = true, [219402] = true, [219403] = true, [219404] = true, [219405] = true, [219406] = true, [219407] = true, [231300] = true, [236663] = true, [240134] = true, [242088] = true, [262007] = true, [277006] = true, [277787] = true, [277788] = true, [277792] = true, [277793] = true, [289645] = true, [302583] = true, [321134] = true, [321395] = true, [334392] = true, [389324] = true, [391027] = true, [391622] = true, [391631] = true, [396392] = true, [460392] = true, [460396] = true, [461489] = true, [468966] = true, [1238306] = true, [1244953] = true, [1295917] = true } },
				{ Id = 82691, File = "RingofFrost.ogg", Name = "Ring of Frost", Ids = { [82691] = true, [221701] = true } },
				{ Id = 31661, File = "DragonBreath.ogg", Name = "Dragon's Breath", Ids = { [31661] = true, [29964] = true, [35250] = true, [37289] = true, [77695] = true, [78521] = true, [83776] = true, [86691] = true, [96447] = true, [161792] = true, [164492] = true, [166965] = true, [169844] = true, [255890] = true, [295240] = true, [371846] = true, [397233] = true, [397234] = true, [397235] = true } },
				{ Id = 122, File = "FrostNova.ogg", Name = "Frost Nova", Ids = { [122] = true, [9915] = true, [11831] = true, [12674] = true, [12748] = true, [14907] = true, [15063] = true, [15531] = true, [15532] = true, [22645] = true, [29849] = true, [30094] = true, [31250] = true, [32192] = true, [32365] = true, [36989] = true, [38033] = true, [39035] = true, [39063] = true, [43426] = true, [44177] = true, [45905] = true, [46555] = true, [57629] = true, [57668] = true, [58458] = true, [59253] = true, [59995] = true, [61376] = true, [61462] = true, [62597] = true, [62605] = true, [63912] = true, [65792] = true, [69060] = true, [69571] = true, [71320] = true, [71929] = true, [75062] = true, [76509] = true, [79850] = true, [100033] = true, [107112] = true, [145532] = true, [155589] = true, [157563] = true, [164067] = true, [164436] = true, [165741] = true, [176276] = true, [176327] = true, [215664] = true, [218253] = true, [220128] = true, [235235] = true, [236601] = true, [250729] = true, [265193] = true, [265584] = true, [268762] = true, [270613] = true, [271817] = true, [278968] = true, [279549] = true, [284879] = true, [287456] = true, [289219] = true, [303308] = true, [363355] = true, [385700] = true, [397236] = true, [397237] = true, [397238] = true, [1271623] = true } },
				{ Id = 353128, File = "arcanosphere.ogg", Name = "Arcanosphere", Ids = { [353128] = true } },
				-- 389831 = stun debuff on victims. Do NOT register 389794 here:
				-- 389794 is the caster's own buff and would self-announce on Frost Mage.
				{ Id = 389831, File = "snowdriftWinter.ogg", Name = "Snowdrift", Ids = { [389831] = true } },
			},
		},
		{
			Key = "Monk",
			Name = "Monk",
			Spells = {
				{ Id = 115078, File = "paralysis.ogg", Name = "Paralysis", Ids = { [115078] = true, [35202] = true, [66830] = true, [84030] = true, [173342] = true, [177578] = true, [213369] = true, [357768] = true } },
				{ Id = 119381, File = "legSweep.ogg", Name = "Leg Sweep", Ids = { [119381] = true, [128787] = true, [164392] = true, [174417] = true, [285270] = true, [292306] = true, [397899] = true, [458605] = true } },
			},
		},
		{
			Key = "Paladin",
			Name = "Paladin",
			Spells = {
				{ Id = 853, File = "hammerofjustice.ogg", Name = "Hammer of Justice", Ids = { [853] = true, [13005] = true, [32416] = true, [37369] = true, [39077] = true, [41468] = true, [66007] = true, [66613] = true, [66940] = true, [77787] = true, [162764] = true, [168010] = true, [180187] = true, [183898] = true, [192220] = true, [210368] = true, [283618] = true, [361625] = true, [389270] = true, [1219295] = true } },
				{ Id = 20066, File = "Repentance.ogg", Name = "Repentance", Ids = { [20066] = true, [29511] = true, [32779] = true, [66008] = true, [81947] = true, [82168] = true, [173315] = true, [263672] = true, [427583] = true } },
				{ Id = 105421, File = "blindingLight.ogg", Name = "Blinding Light", Ids = { [105421] = true, [36950] = true, [152953] = true, [215260] = true, [216692] = true, [279869] = true, [363523] = true, [428170] = true, [1258514] = true } },
				{ Id = 10326, File = "Turnevil.ogg", Name = "Turn Evil", Ids = { [10326] = true, [145067] = true } },
			},
		},
		{
			Key = "Priest",
			Name = "Priest",
			Spells = {
				{ Id = 8122, File = "Fear4.ogg", Name = "Psychic Scream", Ids = { [8122] = true, [13704] = true, [22884] = true, [26042] = true, [27610] = true, [34322] = true, [43432] = true, [65543] = true, [85966] = true, [164443] = true, [165764] = true, [168382] = true, [205605] = true, [216515] = true, [222414] = true, [290105] = true, [306748] = true, [308375] = true, [439873] = true, [1262326] = true } },
				{ Id = 34984, File = "PsychicHorror.ogg", Name = "Psychic Horror", Ids = { [34984] = true, [64044] = true, [65545] = true } },
				{ Id = 605, File = "MindControl.ogg", Name = "Mind Control", Ids = { [605] = true, [36797] = true, [43550] = true, [67229] = true, [136287] = true, [183191] = true, [263073] = true } },
				{ Id = 6726, File = "silence.ogg", Name = "Silence", Ids = { [6726] = true, [8988] = true, [12528] = true, [15487] = true, [18278] = true, [18327] = true, [22666] = true, [23207] = true, [26069] = true, [27559] = true, [29943] = true, [30225] = true, [37160] = true, [38491] = true, [38913] = true, [54093] = true, [56777] = true, [65542] = true, [80967] = true, [207678] = true, [215774] = true, [226452] = true, [329903] = true, [346991] = true, [1234572] = true } },
				{ Id = 200196, File = "chastise.ogg", Name = "Holy Word: Chastise", Ids = { [200196] = true, [200200] = true, [247587] = true } },
				{ Id = 11444, File = "ShackleUndead.ogg", Name = "Shackle Undead", Ids = { [11444] = true, [40135] = true } },
			},
		},
		{
			Key = "Rogue",
			Name = "Rogue",
			Spells = {
				{ Id = 2094, File = "Blind.ogg", Name = "Blind", Ids = { [2094] = true, [21060] = true, [34654] = true, [34694] = true, [42972] = true, [43433] = true, [65960] = true, [127886] = true, [175276] = true, [178058] = true, [214299] = true, [257748] = true, [372407] = true, [427773] = true } },
				{ Id = 6770, File = "sap.ogg", Name = "Sap", Ids = { [6770] = true, [30980] = true, [73154] = true, [134205] = true, [173107] = true, [193082] = true, [257740] = true, [274055] = true, [291391] = true, [292649] = true, [303403] = true, [303406] = true, [324600] = true, [360366] = true, [360958] = true } },
				{ Id = 408, File = "kidney.ogg", Name = "Kidney Shot", Ids = { [408] = true, [27615] = true, [30621] = true, [30832] = true, [32864] = true, [41389] = true, [49616] = true, [72335] = true, [176050] = true, [221792] = true, [283661] = true, [326697] = true, [403644] = true, [415001] = true, [426589] = true, [1229412] = true, [1260833] = true } },
				{ Id = 1833, File = "cheapShot.ogg", Name = "Cheap Shot", Ids = { [1833] = true, [6409] = true, [14902] = true, [30986] = true, [31819] = true, [31843] = true, [34243] = true, [132651] = true, [133002] = true, [138412] = true, [145424] = true, [171953] = true, [188148] = true, [209238] = true, [257738] = true, [263640] = true, [268987] = true, [268993] = true, [283655] = true, [288588] = true, [326696] = true, [374615] = true, [396359] = true, [403988] = true, [1248196] = true, [1257275] = true, [1259727] = true, [1269396] = true, [1289080] = true, [1302853] = true } },
				{ Id = 1776, File = "gouge.ogg", Name = "Gouge", Ids = { [1776] = true, [12540] = true, [13579] = true, [24698] = true, [28456] = true, [29425] = true, [34940] = true, [36862] = true, [38863] = true, [76582] = true, [143301] = true, [143939] = true, [175939] = true, [372410] = true, [1297360] = true } },
				{ Id = 1330, File = "garrote.ogg", Name = "Garrote - Silence", Ids = { [1330] = true, [102926] = true, [128904] = true, [230122] = true, [280322] = true } },
				{ Id = 385627, File = "kingsbane.ogg", Name = "Kingsbane", Ids = { [192759] = true, [214905] = true, [385627] = true } },
				{ Id = 360194, File = "Deathmark.ogg", Name = "Deathmark", Ids = { [360194] = true } },
				{ Id = 207777, File = "disarm.ogg", Name = "Disarm", Ids = { [207777] = true } },
			},
		},
		{
			Key = "Shaman",
			Name = "Shaman",
			Spells = {
				{ Id = 51514, File = "Hex.ogg", Name = "Hex", Ids = { [11641] = true, [16097] = true, [16707] = true, [16708] = true, [16709] = true, [17172] = true, [18503] = true, [22566] = true, [24053] = true, [29044] = true, [36700] = true, [40400] = true, [46295] = true, [51514] = true, [53439] = true, [66054] = true, [76820] = true, [82760] = true, [89459] = true, [97396] = true, [126241] = true, [126345] = true, [133034] = true, [134202] = true, [136422] = true, [142608] = true, [142613] = true, [142617] = true, [150037] = true, [168013] = true, [173156] = true, [178064] = true, [192111] = true, [196942] = true, [210873] = true, [211004] = true, [211010] = true, [211015] = true, [219215] = true, [219216] = true, [219217] = true, [219218] = true, [219219] = true, [247609] = true, [254412] = true, [260052] = true, [262342] = true, [262349] = true, [262362] = true, [269352] = true, [269355] = true, [270492] = true, [271930] = true, [274794] = true, [277778] = true, [277780] = true, [277784] = true, [277785] = true, [278808] = true, [278809] = true, [290438] = true, [309328] = true, [309329] = true, [313639] = true, [332605] = true, [336517] = true, [1256008] = true, [1270766] = true } },
				{ Id = 204437, File = "lightningLasso.ogg", Name = "Lightning Lasso", Ids = { [204437] = true, [305485] = true } },
				{ Id = 118905, File = "capacitor.ogg", Name = "Capacitor Totem", Ids = { [118905] = true } },
			},
		},
		{
			Key = "Warlock",
			Name = "Warlock",
			Spells = {
				{ Id = 118699, File = "Fear.ogg", Name = "Fear", Ids = { [12096] = true, [12542] = true, [22678] = true, [26070] = true, [26580] = true, [26661] = true, [27641] = true, [27990] = true, [29168] = true, [29321] = true, [30002] = true, [30530] = true, [30584] = true, [30615] = true, [31358] = true, [31970] = true, [32241] = true, [33547] = true, [33924] = true, [34259] = true, [38154] = true, [38595] = true, [38660] = true, [39119] = true, [39176] = true, [39210] = true, [39415] = true, [41150] = true, [46561] = true, [51240] = true, [59669] = true, [65809] = true, [68950] = true, [70171] = true, [81442] = true, [113712] = true, [115186] = true, [118699] = true, [125204] = true, [128098] = true, [130616] = true, [130940] = true, [142884] = true, [173093] = true, [182806] = true, [204730] = true, [220540] = true, [221424] = true, [223170] = true, [240136] = true, [242084] = true, [242739] = true, [245902] = true, [248028] = true, [251419] = true, [259874] = true, [259995] = true, [266918] = true, [287685] = true, [288545] = true, [419865] = true, [1259782] = true, [1261911] = true } },
				{ Id = 5484, File = "terrorHowl.ogg", Name = "Howl of Terror", Ids = { [5484] = true, [39048] = true, [130923] = true, [138562] = true, [178072] = true, [1267008] = true } },
				{ Id = 6789, File = "mortalCoil.ogg", Name = "Mortal Coil", Ids = { [6789] = true, [295459] = true, [361064] = true } },
				{ Id = 710, File = "Banish.ogg", Name = "Banish", Ids = { [710] = true, [8994] = true, [27565] = true, [37527] = true, [37833] = true, [38009] = true, [38791] = true, [39622] = true, [39674] = true, [40370] = true, [44765] = true, [44836] = true, [71298] = true, [136466] = true, [181746] = true, [183578] = true, [464333] = true } },
				{ Id = 6358, File = "seduction.ogg", Name = "Seduction", Ids = { [6358] = true, [29490] = true, [30850] = true, [31865] = true, [86377] = true, [86545] = true, [176177] = true, [183763] = true, [230159] = true, [238428] = true, [241799] = true, [261589] = true, [1201554] = true } },
				{ Id = 6466, File = "AxeToss.ogg", Name = "Axe Toss", Ids = { [6466] = true, [89766] = true, [193824] = true, [325820] = true } },
				{ Id = 30283, File = "shadowFury.ogg", Name = "Shadowfury", Ids = { [30283] = true, [45270] = true, [81441] = true, [320132] = true } },
			},
		},
		{
			Key = "Warrior",
			Name = "Warrior",
			Spells = {
				{ Id = 5246, File = "Fear3.ogg", Name = "Intimidating Shout", Ids = { [5246] = true, [65930] = true, [65931] = true, [95199] = true, [97933] = true, [97934] = true, [155582] = true, [164464] = true, [164465] = true, [167259] = true, [167261] = true, [169432] = true, [223169] = true, [236353] = true, [240190] = true, [273867] = true, [316593] = true, [316595] = true, [372405] = true, [397242] = true, [397243] = true, [397244] = true, [1253030] = true } },
				{ Id = 167105, File = "colossusSmash.ogg", Name = "Colossus Smash", Ids = { [167105] = true, [208086] = true, [262161] = true } },
				{ Id = 236077, File = "disarm.ogg", Name = "Disarm", Ids = { [236077] = true, [236236] = true } },
				{ Id = 20685, File = "stormBolt.ogg", Name = "Storm Bolt", Ids = { [20685] = true, [55958] = true, [61628] = true, [84831] = true, [132169] = true, [133396] = true, [139275] = true, [222897] = true, [259867] = true, [317277] = true, [348599] = true, [1240116] = true } },
				{ Id = 25425, File = "shockwave.ogg", Name = "Shockwave", Ids = { [25425] = true, [33686] = true, [55636] = true, [55918] = true, [57728] = true, [57741] = true, [58947] = true, [58977] = true, [75343] = true, [75417] = true, [79872] = true, [83785] = true, [84715] = true, [86699] = true, [87759] = true, [88846] = true, [93325] = true, [99610] = true, [107102] = true, [108046] = true, [126833] = true, [129785] = true, [131570] = true, [132168] = true, [136847] = true, [139215] = true, [140446] = true, [145047] = true, [162634] = true, [164092] = true, [165751] = true, [165954] = true, [188284] = true, [189539] = true, [207979] = true, [210506] = true, [235692] = true, [236347] = true, [257404] = true, [269341] = true, [277161] = true, [298630] = true, [308890] = true, [330458] = true, [337347] = true, [342875] = true, [346605] = true } },
			},
		},
	},
}
