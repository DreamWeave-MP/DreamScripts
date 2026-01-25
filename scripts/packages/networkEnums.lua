---@class Enumerations
local enumerations = {}

---@enum AIState
enumerations.ai = { CANCEL = 0, ACTIVATE = 1, COMBAT = 2, ESCORT = 3, FOLLOW = 4, TRAVEL = 5, WANDER = 6 }

---@enum AIPrintableAction
enumerations.aiPrintableAction = {
    CANCEL = 'cancelling current AI',
    ACTIVATE = 'activating',
    COMBAT = 'initiating combat with',
    ESCORT = 'escorting',
    FOLLOW = 'following',
    TRAVEL = 'travelling to',
    WANDER = 'wandering',
}

---@enum ContainerAction
enumerations.container = { SET = 0, ADD = 1, REMOVE = 2, REQUEST = 3 }

---@enum ContainerSubAction
enumerations.containerSub = { NONE = 0, DRAG = 1, DROP = 2, TAKE_ALL = 3, REPLY_TO_REQUEST = 4, RESTOCK_RESULT = 5 }

---@enum DialogueChoice
enumerations.dialogueChoice = {
    TOPIC = 0,
    PERSUASION = 1,
    COMPANION_SHARE = 2,
    BARTER = 3,
    SPELLS = 4,
    TRAVEL = 5,
    SPELLMAKING = 6,
    ENCHANTING = 7,
    TRAINING = 8,
    REPAIR = 9
}

---@enum DoorState
enumerations.doorstate = { OPEN = 1, CLOSED = 2 }

---@enum ActorStance
enumerations.drawstate = { NONE = 0, WEAPON = 1, SPELL = 2 }

---@enum FactionAction
enumerations.faction = { RANK = 0, EXPULSION = 1, REPUTATION = 2 }

---@enum InventoryActionType
enumerations.inventory = { SET = 0, ADD = 1, REMOVE = 2 }

---@enum JournalType
enumerations.journal = { ENTRY = 0, INDEX = 1 }

---@enum LogLevel
enumerations.log = { NONE = -1, VERBOSE = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4 }

---@enum MiscEnum
enumerations.miscellaneous = { MARK_LOCATION = 0, SELECTED_SPELL = 1 }

---@enum WorldObjectCategory
enumerations.objectCategories = { PLAYER = 0, ACTOR = 1, PLACED_OBJECT = 2 }

---@enum PacketOriginType
enumerations.packetOrigin = {
    CLIENT_GAMEPLAY = 0,
    CLIENT_CONSOLE = 1,
    CLIENT_DIALOGUE = 2,
    CLIENT_SCRIPT_LOCAL = 3,
    CLIENT_SCRIPT_GLOBAL = 4,
    SERVER_SCRIPT = 5
}

---@enum RecordType
enumerations.recordType = {
    ACTIVATOR = 0,
    APPARATUS = 1,
    ARMOR = 2,
    BODYPART = 3,
    BOOK = 4,
    CELL = 5,
    CLOTHING = 6,
    CONTAINER = 7,
    CREATURE = 8,
    DOOR = 9,
    ENCHANTMENT = 10,
    GAMESETTING = 11,
    INGREDIENT = 12,
    LIGHT = 13,
    LOCKPICK = 14,
    MISCELLANEOUS = 15,
    NPC = 16,
    POTION = 17,
    PROBE = 18,
    REPAIR = 19,
    SCRIPT = 20,
    SOUND = 21,
    SPELL = 22,
    STATIC = 23,
    WEAPON = 24
}

---@enum ResurrectType
enumerations.resurrect = { REGULAR = 0, IMPERIAL_SHRINE = 1, TRIBUNAL_TEMPLE = 2 }

---@enum SpellbookAction
enumerations.spellbook = { SET = 0, ADD = 1, REMOVE = 2 }

---@enum StaffRank
enumerations.staffRank = { NONE = 0, MODERATOR = 1, ADMIN = 2, OWNER = 3, }

---@enum MWScriptVarType
enumerations.variableType = { SHORT = 0, LONG = 1, FLOAT = 2, INT = 3, STRING = 4 }

---@enum WeatherType
enumerations.weather = {
    CLEAR = 0,
    CLOUDY = 1,
    FOGGY = 2,
    OVERCAST = 3,
    RAIN = 4,
    THUNDER = 5,
    ASH = 6,
    BLIGHT = 7,
    SNOW = 8,
    BLIZZARD = 9
}

return enumerations
