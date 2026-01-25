local tableHelper = require 'packages.tableHelper'

---@alias SpeechSubfolder 'default'|string
---@alias SpeechSubDirCollection table<string, SpeechDirDetails>

--- Class representing a collection of individual speech files for a given race/subdirectory combination
---@class SpeechDirDetails
---@field count integer number of files in this collectoin
---@field filePrefixOverride string? Optional override for directory names when constructing file paths
---@field skip integer[]? Optional list of speech files to skip which don't exist

---@class ContentFileSpeechCollection
---@field folderPath string The subdirectory of vo/ in which this speech collection lives
---@field malePrefix string file name prefix for male voice lines
---@field femalePrefix string? file name prefix for female voice lines
---@field maleFiles SpeechSubDirCollection speech file listing for males
---@field femaleFiles SpeechSubDirCollection? speech file listing for females

if not ClientDataFiles then
    ClientDataFiles = require('dUtil').loadRequiredDataFiles(false)
end

---@type table<MWRace, table<SpeechSubfolder, ContentFileSpeechCollection>>
local speechCollections = {}

if tableHelper.containsCaseInsensitiveString(ClientDataFiles, 'Morrowind.esm') then
    speechCollections['argonian'] = {
        default = {
            folderPath = 'a',
            malePrefix = 'AM',
            femalePrefix = 'AF',
            maleFiles = {
                attack = { count = 15 },
                flee = { count = 5 },
                follower = { count = 3 },
                hello = { count = 139 },
                hit = { count = 16, skip = { 11 } },
                idle = { count = 8 },
                intruder = { count = 9, skip = { 7 }, indexPrefixOverride = 'OP' },
                service = { count = 12 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 17, skip = { 11, 15, 16 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 139 },
                hit = { count = 16 },
                idle = { count = 8 },
                oppose = { count = 8 },
                service = { count = 12 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['breton'] = {
        default = {
            folderPath = 'b',
            malePrefix = 'BM',
            femalePrefix = 'BF',
            maleFiles = {
                attack = { count = 15, skip = { 11 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138, skip = { 126 } },
                hit = { count = 15 },
                idle = { count = 8 },
                intruder = { count = 9, skip = { 7 }, indexPrefixOverride = 'OP' },
                service = { count = 12 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 15, skip = { 11 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 15 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['dark elf'] = {
        default = {
            folderPath = 'd',
            malePrefix = 'DM',
            femalePrefix = 'DF',
            maleFiles = {
                attack = { count = 14 },
                flee = { count = 6 },
                follower = { count = 4 },
                hello = { count = 233 },
                hit = { count = 14 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 52 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 13 },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 233 },
                hit = { count = 14, skip = { 7 } },
                idle = { count = 9, skip = { 7, 8 } },
                oppose = { count = 8 },
                service = { count = 51 },
                thief = { count = 3, skip = { 1, 2 } }
            }
        },
        ord = {
            folderPath = 'ord',
            malePrefix = 'ORM',
            maleFiles = {
                attack = { count = 5 },
                hello = { count = 20 },
                idle = { count = 4 },
                intruder = { count = 2 }
            }
        }
    }

    speechCollections['high elf'] = {
        default = {
            folderPath = 'h',
            malePrefix = 'HM',
            femalePrefix = 'HF',
            maleFiles = {
                attack = { count = 15 },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 15, skip = { 14 } },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 25 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 15 },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 8 },
                oppose = { count = 8 },
                service = { count = 18 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['imperial'] = {
        default = {
            folderPath = 'i',
            malePrefix = 'IM',
            femalePrefix = 'IF',
            maleFiles = {
                attack = { count = 14 },
                flee = { count = 4 },
                follower = { count = 3 },
                hello = {
                    count = 179,
                    skip = { 1, 27, 47, 69, 70, 71, 72, 80, 81, 82, 83, 84, 85, 86,
                        100, 101, 102, 103, 104, 105, 106, 107, 128, 129, 143, 144, 145, 171, 173, 174, 176 }
                },
                hit = { count = 10 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 34 },
                thief = { count = 5 },
                uniform = { count = 7 }
            },
            femaleFiles = {
                attack = { count = 15, skip = { 11 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 173, skip = { 159, 163 } },
                hit = { count = 15 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 21 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['khajiit'] = {
        default = {
            folderPath = 'k',
            malePrefix = 'KM',
            femalePrefix = 'KF',
            maleFiles = {
                attack = { count = 15, skip = { 11 } },
                flee = { count = 5 },
                follower = { count = 3 },
                hello = { count = 139 },
                hit = { count = 16 },
                idle = { count = 9 },
                intruder = { count = 9, skip = { 7 }, indexPrefixOverride = 'OP' },
                service = { count = 9 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 15, skip = { 11 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 139 },
                hit = { count = 16 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 12 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['nord'] = {
        default = {
            folderPath = 'n',
            malePrefix = 'NM',
            femalePrefix = 'NF',
            maleFiles = {
                attack = { count = 20, skip = { 14, 15, 16, 17, 18, 19 } },
                flee = { count = 5 },
                follower = { count = 4 },
                hello = { count = 138 },
                hit = { count = 14 },
                idle = { count = 9 },
                intruder = { count = 9, skip = { 7 }, indexPrefixOverride = 'OP' },
                service = { count = 6 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 15, skip = { 11 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 11 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['orc'] = {
        default = {
            folderPath = 'o',
            malePrefix = 'OM',
            femalePrefix = 'OF',
            maleFiles = {
                attack = { count = 15 },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 12 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 15 },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 21 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 3 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['redguard'] = {
        default = {
            folderPath = 'r',
            malePrefix = 'RM',
            femalePrefix = 'RF',
            maleFiles = {
                attack = { count = 18 },
                flee = { count = 5 },
                follower = { count = 3 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 9 },
                intruder = { count = 9, skip = { 7 }, indexPrefixOverride = 'OP' },
                service = { count = 12 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 15, skip = { 1, 11 } },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 14 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 6 },
                thief = { count = 5 }
            }
        }
    }

    speechCollections['wood elf'] = {
        default = {
            folderPath = 'w',
            malePrefix = 'WM',
            femalePrefix = 'WF',
            maleFiles = {
                attack = { count = 18, skip = { 14, 15, 16, 17 } },
                flee = { count = 5 },
                follower = { count = 3 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 9 },
                intruder = { count = 9, skip = { 7 }, indexPrefixOverride = 'OP' },
                service = { count = 6 },
                thief = { count = 5 }
            },
            femaleFiles = {
                attack = { count = 14 },
                flee = { count = 5 },
                follower = { count = 6 },
                hello = { count = 138 },
                hit = { count = 15 },
                idle = { count = 9 },
                oppose = { count = 8 },
                service = { count = 9 },
                thief = { count = 5 }
            }
        }
    }
end

if tableHelper.containsCaseInsensitiveString(ClientDataFiles, 'Tribunal.esm') then
    speechCollections['dark elf']['tb'] = {
        folderPath = 'd',
        malePrefix = 'DM',
        femalePrefix = 'DF',
        maleFiles = {
            hello = { count = 200, filePrefixOverride = 'tHlo' },
            idle = { count = 24, filePrefixOverride = 'tIdl' }
        },
        femaleFiles = {
            hello = { count = 173, filePrefixOverride = 'tHlo' },
            idle = { count = 17, filePrefixOverride = 'tIdl' }
        }
    }

    speechCollections['imperial']['tb'] = {
        folderPath = 'i',
        malePrefix = 'IM',
        femalePrefix = 'IF',
        maleFiles = {
            hello = { count = 116, filePrefixOverride = 'tHlo' },
            idle = { count = 13, filePrefixOverride = 'tIdl' }
        },
        femaleFiles = {
            hello = { count = 112, filePrefixOverride = 'tHlo' },
            idle = { count = 13, filePrefixOverride = 'tIdl' }
        }
    }
end

if tableHelper.containsCaseInsensitiveString(ClientDataFiles, 'Bloodmoon.esm') then
    speechCollections['dark elf']['bm'] = {
        folderPath = 'd',
        malePrefix = 'DM',
        femalePrefix = 'DF',
        maleFiles = {
            attack = { count = 6, filePrefixOverride = 'bAtk' },
            flee = { count = 4, filePrefixOverride = 'bFle' },
            hello = { count = 7, filePrefixOverride = 'bHlo' },
            idle = { count = 14, skip = { 1 }, filePrefixOverride = 'bIdl' }
        },
        femaleFiles = {
            attack = { count = 6, filePrefixOverride = 'bAtk' },
            flee = { count = 4, filePrefixOverride = 'bFle' },
            hello = { count = 1, filePrefixOverride = 'bHlo' },
            idle = { count = 15, skip = { 7, 8 }, filePrefixOverride = 'bIdl' }
        }
    }

    speechCollections['imperial']['bm'] = {
        folderPath = 'i',
        malePrefix = 'IM',
        femalePrefix = 'IF',
        maleFiles = {
            attack = { count = 9, filePrefixOverride = 'bAtk' },
            flee = { count = 4, filePrefixOverride = 'bFle' },
            hello = { count = 52, filePrefixOverride = 'bHlo' },
            idle = { count = 41, skip = { 16 }, filePrefixOverride = 'bIdl' }
        },
        femaleFiles = {
            attack = { count = 8, filePrefixOverride = 'bAtk' },
            flee = { count = 4, filePrefixOverride = 'bFle' },
            hello = { count = 17, skip = { 8, 9, 10 }, filePrefixOverride = 'bHlo' },
            idle = { count = 13, filePrefixOverride = 'bIdl' }
        }
    }

    speechCollections['nord']['bm'] = {
        folderPath = 'n',
        malePrefix = 'NM',
        femalePrefix = 'NF',
        maleFiles = {
            attack = { count = 9, filePrefixOverride = 'bAtk' },
            flee = { count = 4, filePrefixOverride = 'bFle' },
            hello = { count = 75, filePrefixOverride = 'bHlo' },
            idle = { count = 37, filePrefixOverride = 'bIdl' }
        },
        femaleFiles = {
            attack = { count = 9, filePrefixOverride = 'bAtk' },
            flee = { count = 4, filePrefixOverride = 'bFle' },
            hello = { count = 21, skip = { 8, 9 }, filePrefixOverride = 'bHlo' },
            idle = { count = 23, skip = { 21 }, filePrefixOverride = 'bIdl' }
        }
    }
end

if tableHelper.containsCaseInsensitiveString(ClientDataFiles, "Starwind-TSI.omwaddon") then
    speechCollections["arkanian"] = {
        default = {
            folderPath = "Starwind\\Arkanian",
            maleFiles = {
                attack = { count = 9 },
                hello = { count = 9 },
                idle = { count = 9 },
                hit = { count = 7, filePrefixOverride = "O" }
            },
            femaleFiles = {
                attack = { count = 9 },
                hello = { count = 9 },
                idle = { count = 9 },
                hit = { count = 8, filePrefixOverride = "Hu" }
            },
        }
    }

    speechCollections["arkanian"]["mr"] = {
        folderPath = "Starwind\\Arkanian\\MR",
        skipGenderAssign = { "skip" },
        maleFiles = {
            attack = { count = 8 },
            hello = { count = 16 },
            idle = { count = 9 },
        },
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 16 },
            idle = { count = 9 },
        },
    }

    -- Tarisian
    speechCollections["breton"] = {
        default = {
            folderPath = "Starwind\\Type4",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8, needsIndexSuffixOverride = { 6 }, indexSuffixOverride = "]" }
            },
            femaleFiles = {
                attack = { count = 7 },
                hello = { count = 8 },
                idle = { count = 7 },
                hit = { count = 8, }
            },
        }
    }

    speechCollections["droid"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Droid\\M",
            maleFiles = {
                attack = { count = 32, skip = { 2 } },
                hello = { count = 17 },
                idle = { count = 17 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 32, skip = { 2 } },
                hello = { count = 17 },
                idle = { count = 17 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["droid"]["lu"] = {
        folderPath = "Starwind\\Droid",
        skipGenderAssign = { "skip" },
        maleFiles = {
            attack = { count = 8, filePrefixOverride = "Attack" },
            hello = { count = 9, skip = { 6 }, addSpace = { 1, 2 }, filePrefixOverride = "Hello" }
        },
        femaleFiles = {
            attack = { count = 8, filePrefixOverride = "Attack" },
            hello = { count = 9, skip = { 6 }, addSpace = { 1, 2 }, filePrefixOverride = "Hello" }
        },
    }
    --Duros
    speechCollections["dark elf"] = {
        default = {
            folderPath = "Starwind\\Duros",
            maleFiles = {
                attack = { count = 24 },
                hello = { count = 32, needsIndexSuffixOverride = { 18 }, indexSuffixOverride = "N" },
                idle = { count = 25 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 24 },
                hello = {
                    count = 34,
                    needsIndexSuffixOverride = { 10, 22, 25 },
                    indexSuffixOverride = "N",
                    skip = { 11, 23 },
                    fullOverride = { 26 },
                    fullOverrideValue = "H25NN",
                    decrementIndex = { 27, 28, 29, 30, 31, 32, 33, 34 }
                },
                idle = { count = 24, needsIndexSuffixOverride = { 20, 22 }, indexSuffixOverride = "N" },
                hit = { count = 8 }
            },
        }
    }
    --Cathar
    speechCollections["khajiit"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Cathar\\M",
            maleFiles = {
                attack = { count = 16 },
                hello = { count = 24 },
                idle = { count = 16 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 16 },
                hello = { count = 24 },
                idle = { count = 16 },
                hit = { count = 8 }
            },
        }
    }
    -- Gungan
    speechCollections["argonian"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Gungan",
            maleFiles = {
                attack = { count = 16 },
                hello = { count = 23 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 16 },
                hello = { count = 23 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
        }
    }
    --Gungan
    speechCollections["argonian"]["sdf"] = {
        skipGenderAssign = { "skip" },
        folderPath = "Starwind\\GunganSDF",
        maleFiles = {
            attack = { count = 8 },
            hello = { count = 8 },
        },
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 8 },
        },
    }

    speechCollections["bith"] = {
        default = {
            folderPath = "Starwind\\Bith",
            maleFiles = {
                attack = { count = 16 },
                hello = { count = 24 },
                idle = { count = 18 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 16 },
                hello = { count = 24 },
                idle = { count = 18 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["chagrian"] = {
        default = {
            folderPath = "Starwind\\Chagrian",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["chiss"] = {
        default = {
            folderPath = "Starwind\\Chiss",
            maleFiles = {
                attack = { count = 24 },
                hello = { count = 40 },
                idle = { count = 24 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 24 },
                hello = { count = 40 },
                idle = { count = 25 },
                hit = { count = 8 }
            },
        }
    }

    --coruscanti
    speechCollections["imperial"] = {
        default = {
            folderPath = "Starwind\\Type1", --TODO add Type3 to imperial...
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8, needsIndexSuffixOverride = { 3 }, indexSuffixOverride = "'" },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["imperial"]["mcc"] = {
        folderPath = "Starwind\\Type3",
        skipGenderAssign = { "skip" },
        maleFiles = {
            attack = { count = 7 },
            f = { count = 1, noIndex = { 1 } },
            hello = { count = 8 },
            idle = { count = 8 },
            hit = { count = 8 }
        }
    }

    speechCollections["imperial"]["fcc"] = {
        folderPath = "Starwind\\Type3F",
        skipGenderAssign = { "skip" },
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 8 },
            idle = { count = 8 },
            hit = { count = 8 }
        }
    }

    speechCollections["cow"] = {
        default = {
            folderPath = "",
            skipGenderAssign = { "skip" },
            maleFiles = {
                moo = { count = 1, cow = { 1 } }
            },
            femaleFiles = {
                moo = { count = 1, cow = { 1 } }
            },
        }
    }

    speechCollections["sw_cyborg"] = {
        default = {
            folderPath = "Starwind\\Cyborg",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["sw_cyborg"]["cc"] = {
        folderPath = "Starwind\\CyborgCC",
        maleFiles = {
            attack = { count = 9 },
            hello = { count = 9 },
            idle = { count = 8 },
            hit = { count = 8 }
        }
    }
    speechCollections["sw_cyborg"]["rs"] = {
        folderPath = "Starwind\\CyborgRS",
        maleFiles = {
            attack = { count = 8 },
            hello = { count = 14 },
            idle = { count = 8 },
            hit = { count = 8 }
        },
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 15 },
            idle = { count = 8 },
            hit = { count = 8 }
        },
    }

    speechCollections["ewok"] = {
        default = {
            folderPath = "Starwind\\Ewok",
            skipGenderAssign = { "skip" },
            maleFiles = {
                attack = { count = 4 },
                hello = { count = 4, needsIndexSuffixOverride = { 2 }, indexSuffixOverride = "'" },
                idle = { count = 1 },
                hit = { count = 4 }
            },
            femaleFiles = {
                attack = { count = 4 },
                hello = { count = 4, needsIndexSuffixOverride = { 2 }, indexSuffixOverride = "'" },
                idle = { count = 1 },
                hit = { count = 4 }
            },

        }
    }
    --Mandalorian
    speechCollections["nord"] = {
        default = {
            folderPath = "Starwind\\Type7",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8, needsIndexSuffixOverride = { 6 }, indexSuffixOverride = ".7", incrementIndex = 6 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
        }
    }
    --gammorean
    speechCollections["goomorena"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Gomorrean",
            maleFiles = {
                hello = { count = 8 },
                oink = { count = 8 }
            },
            femaleFiles = {
                hello = { count = 8 },
                oink = { count = 8 }
            },
        }
    }

    speechCollections["gran"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Gran\\M",
            maleFiles = {
                attack = { count = 18 },
                hello = { count = 24 },
                idle = { count = 13 },
                hit = { count = 9, skip = { 7 } }
            },
            femaleFiles = {
                attack = { count = 18 },
                hello = { count = 24 },
                idle = { count = 13 },
                hit = { count = 9, skip = { 7 } }
            },
        }
    }
    --Twi'lek (Yellow)
    speechCollections["high elf"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\TwilekY\\M",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["ithorian"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Ithorian",
            maleFiles = {
                attack = { count = 2 },
                hello = { count = 4 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 2 },
                hello = { count = 4 },
                hit = { count = 8 }
            },
        }
    }

    --jawa
    speechCollections["jewa"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Jawa",
            maleFiles = {
                die = { count = 1, noIndex = { 1 } },
                hli = { count = 1, noIndex = { 1 } },
                jua = { count = 1, noIndex = { 1 } },
                maloo = { count = 1, noIndex = { 1 } },
                muum = { count = 1, noIndex = { 1 } },
                utini = { count = 1, noIndex = { 1 } },
                wauh = { count = 1, noIndex = { 1 } },
                yuamikee = { count = 1, noIndex = { 1 } },
                ibana = { count = 2, noIndex = { 1 } },
                hurt = { count = 5 }
            },
            femaleFiles = {
                die = { count = 1, noIndex = { 1 } },
                hli = { count = 1, noIndex = { 1 } },
                jua = { count = 1, noIndex = { 1 } },
                maloo = { count = 1, noIndex = { 1 } },
                muum = { count = 1, noIndex = { 1 } },
                utini = { count = 1, noIndex = { 1 } },
                wauh = { count = 1, noIndex = { 1 } },
                yuamikee = { count = 1, noIndex = { 1 } },
                ibana = { count = 2, noIndex = { 1 } },
                hurt = { count = 5 }
            },
        }
    }

    --kel dor
    speechCollections["keldor"] = {
        default = {
            folderPath = "Starwind\\Kel Dor",
            maleFiles = {
                attack = { count = 16 },
                hello = { count = 23 },
                idle = { count = 16 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 16 },
                hello = { count = 24 },
                idle = { count = 16 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["miraluka"] = {
        default = {
            folderPath = "Starwind\\Miraluka",
            maleFiles = {
                attack = { count = 16 },
                hello = { count = 8 },
                idle = { count = 16 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 15 },
                hello = { count = 8 },
                idle = { count = 16 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["nikto"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Nikto\\M",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 7 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 7 },
                hit = { count = 8 }
            },
        }
    }

    --rodian
    speechCollections["orc"] = {
        default = {
            folderPath = "Starwind\\Rodian",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["sand person"] = {
        default = {
            folderPath = "Starwind\\Sand",
            maleFiles = {
                attack = { count = 8, filePrefixOverride = "" },
                hello = { count = 3 },
                t = { count = 3 }
            },
            femaleFiles = {
                attack = { count = 9, filePrefixOverride = "" },
                hello = { count = 1, noIndex = { 1 } },
                idle = { count = 1, noIndex = { 1 } },
                j = { count = 1, noIndex = { 1 } },
                k = { count = 1, noIndex = { 1 } },
                l = { count = 1, noIndex = { 1 } },
            },
        }
    }

    speechCollections["selkath"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Selkath",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["sith"] = {
        default = {
            folderPath = "Starwind\\SithT",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 16 },
                idle = { count = 9 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 16 },
                idle = { count = 8 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["sith"]["fe"] = {
        skipGenderAssign = { "skip" },
        folderPath = "Starwind\\Sith\\F",
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 8 },
            idle = { count = 8 },
            hit = { count = 8 }
        },
    }

    speechCollections["sith"]["ch"] = {
        skipGenderAssign = { "skip" },
        folderPath = "Starwind\\SithTrooperTT",
        maleFiles = {
            stt = { count = 5, waveFile = { 1, 2, 3, 4, 5 }, filePrefixOverride = "" },
        },
    }

    speechCollections["twi'lekblue"] = {
        default = {
            folderPath = "Starwind\\TwilekB",
            maleFiles = {
                attack = { count = 24 },
                hello = { count = 32 },
                idle = { count = 24 },
                hit = { count = 8 }
            },
            femaleFiles = {
                attack = { count = 24 },
                hello = { count = 32 },
                idle = { count = 24 },
                hit = { count = 8 }
            },
        }
    }

    speechCollections["togruta"] = {
        default = {
            folderPath = "Starwind\\Togruta",
            maleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8, filePrefixOverride = "Hu" }
            },
            femaleFiles = {
                attack = { count = 8 },
                hello = { count = 8 },
                idle = { count = 8 },
                hit = { count = 8, filePrefixOverride = "Hu" }
            },
        }
    }

    speechCollections["togruta"]["r"] = {
        folderPath = "Starwind\\TogrutaR",
        maleFiles = {
            attack = { count = 8 },
            hello = { count = 16 },
            idle = { count = 8 },
            hit = { count = 8 }
        },
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 16 },
            idle = { count = 8 }
        },
    }

    speechCollections["wookie"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Wookie",
            maleFiles = {
                attack = { count = 4, filePrefixOverride = "WookieA", fullOverride = { 3 }, fullOverrideValue = "WookeA3" },
                hello = { count = 5, filePrefixOverride = "WookieH", fullOverride = { 3 }, fullOverrideValue = "wOOKIEH3" },
                hit = { count = 4, filePrefixOverride = "WookieP" }
            },
            femaleFiles = {
                attack = { count = 4, filePrefixOverride = "WookieA", fullOverride = { 3 }, fullOverrideValue = "WookeA3" },
                hello = { count = 5, filePrefixOverride = "WookieH", fullOverride = { 3 }, fullOverrideValue = "wOOKIEH3" },
                hit = { count = 4, filePrefixOverride = "WookieP" }
            },
        }
    }

    speechCollections["zabrak"] = {
        default = {
            skipGenderAssign = { "skip" },
            folderPath = "Starwind\\Zabrak\\Male",
            maleFiles = {
                attack = { count = 10 },
                hello = { count = 7 },
                hit = { count = 7, filePrefixOverride = "HU", fullOverride = { 1, 3 }, fullOverrideValue = "HU", includeIndexInFullOverride = "true" },
                idle = { count = 10 }
            },
        }
    }

    speechCollections["zabrak"]["f"] = {
        skipGenderAssign = { "skip" },
        folderPath = "Starwind\\Zabrak\\Fem",
        femaleFiles = {
            attack = { count = 8 },
            hello = { count = 7 },
            hit = { count = 7, filePrefixOverride = "Hu" },
            idle = { count = 10 }
        },
    }

    speechCollections["zabrak"]["r"] = {
        skipGenderAssign = { "skip" },
        folderPath = "Starwind\\ZabrakR\\M",
        maleFiles = {
            attack = { count = 8 },
            hello = { count = 16 },
            hit = { count = 8 },
            idle = { count = 8 }
        },
    }

    -- NOTE: Not yet implemented:
    -- E_BattleDroid
    -- Chargrian
    -- Devaronian
    -- Lothalite (Redguard)
    -- Moncalamari
    -- Nautolan
    -- Protocol Droid
    -- Trandoshan
    -- Tribal ewok
    -- Twi'lek(red)

    speechCollections["swe_assassindroid"] = {}
    speechCollections["e_battledroid"] = {}
    speechCollections["chargrian"] = {}
    speechCollections["swe_devaronian"] = {}
    speechCollections["redguard"] = {}
    speechCollections["moncalamari"] = {}
    speechCollections["nautolan"] = {}
    speechCollections["e_protocoldroid"] = {}
    speechCollections["swe_trandoshan"] = {}
    speechCollections["e_ewok2"] = {}
    speechCollections["swe_sithtwilek"] = {}
end

---@class SpeechHelper
local speechHelper = {}

---@enum SpeechPrefixes
local speechTypesToFilePrefixes = {
    attack = 'Atk',
    flee = 'Fle',
    follower = 'Flw',
    hello = 'Hlo',
    hit = 'Hit',
    idle = 'Idl',
    intruder = 'int',
    oppose = 'OP',
    service = 'Srv',
    thief = 'Thf',
    uniform = 'uni'
}

--- Given a speech collection table, prefix, index, and gender, get the matching speech path
---@param speechCollectionTable ContentFileSpeechCollection
---@param speechType string
---@param speechIndex integer
---@param gender MWGender
function speechHelper.GetSpeechPathFromCollection(speechCollectionTable, speechType, speechIndex, gender)
    if not speechCollectionTable or not speechTypesToFilePrefixes[speechType] then return end

    local genderTableName

    if gender == 0 then
        genderTableName = 'femaleFiles'
    else
        genderTableName = 'maleFiles'
    end

    local speechTypeTable = speechCollectionTable[genderTableName][speechType]

    if not speechTypeTable then
        return
    end

    if speechIndex > speechTypeTable.count then
        return
    elseif speechTypeTable.skip and tableHelper.containsValue(speechTypeTable.skip, speechIndex) then
        return
    end

    local speechPath = 'Vo\\' .. speechCollectionTable.folderPath .. '\\'

    -- Assume there are only going to be subfolders for different genders if there are actually
    -- speech files for both genders
    if speechCollectionTable.maleFiles and speechCollectionTable.femaleFiles then
        if gender == 0 then
            speechPath = speechPath .. 'f\\'
        else
            speechPath = speechPath .. 'm\\'
        end
    end

    local filePrefix

    if speechTypeTable.filePrefixOverride then
        filePrefix = speechTypeTable.filePrefixOverride
    else
        filePrefix = speechTypesToFilePrefixes[speechType]
    end

    local indexPrefix

    if speechTypeTable.indexPrefixOverride then
        indexPrefix = speechTypeTable.indexPrefixOverride
    elseif gender == 0 then
        indexPrefix = speechCollectionTable.femalePrefix
    else
        indexPrefix = speechCollectionTable.malePrefix
    end

    speechPath = speechPath .. filePrefix .. '_' .. indexPrefix .. speechIndex:prefixZeroes(3) .. '.mp3'

    return speechPath
end

--- Given a pid, a path to a speech collection, and an index to it, return a fully--constructed speech path for input into tes3mp.PlaySpeech
---@param pid PlayerId
---@param speechInput string
---@param speechIndex integer
---@return string? speechPath If a matching speech path was found, this is its fully-constructed VFS path
function speechHelper.GetSpeechPath(pid, speechInput, speechIndex)
    local speechCollectionKey
    local speechType

    -- Is there a specific folder at the start of the speechInput? If so,
    -- get the speechCollectionKey from it
    local underscoreIndex = speechInput:find('_')

    if underscoreIndex and underscoreIndex > 1 then
        speechCollectionKey = speechInput:sub(1, underscoreIndex - 1)
        speechType = speechInput:sub(underscoreIndex + 1)
    else
        speechCollectionKey = 'default'
        speechType = speechInput
    end

    local race = Players[pid].data.character.race:lower()
    local speechCollectionTable = speechCollections[race][speechCollectionKey]

    if not speechCollectionTable then return end

    local gender = Players[pid].data.character.gender

    return speechHelper.GetSpeechPathFromCollection(speechCollectionTable, speechType, speechIndex, gender)
end

--- Given a speech collection table, a gender, and an optional collection prefix, return printable list of all valid speeches in the collection
---@param speechCollectionTable ContentFileSpeechCollection
---@param gender MWGender
---@param collectionPrefix string? optional prefix to append to this speech collection
---@return string[] speechList Array of all valid speech paths for this collection
function speechHelper.GetPrintableValidListForSpeechCollection(speechCollectionTable, gender, collectionPrefix)
    local validList = {}
    local genderTableName

    if gender == 0 then
        genderTableName = 'femaleFiles'
    else
        genderTableName = 'maleFiles'
    end

    local genderedSpeechCollection = speechCollectionTable[genderTableName]
    if genderedSpeechCollection then
        for speechType, typeDetails in pairs(genderedSpeechCollection) do
            local validInput

            if typeDetails.skip then
                validInput = ('%s%s1-%s (except %s)')
                    :format(collectionPrefix or '', speechType, typeDetails.count,
                        tableHelper.concatenateFromIndex(typeDetails.skip, 1, ', ')
                    )
            else
                validInput = ('%s%s1-%s'):format(collectionPrefix or '', speechType, typeDetails.count)
            end

            table.insert(validList, validInput)
        end
    end

    return validList
end

---@param pid PlayerId
---@return string speechList printable list of all possible speeches for this PlayerId
function speechHelper.GetPrintableValidListForPid(pid)
    local validList = {}

    local race = Players[pid].data.character.race:lower()
    local gender = Players[pid].data.character.gender

    -- Print the default speech options first
    if speechCollections[race].default then
        validList = speechHelper.GetPrintableValidListForSpeechCollection(speechCollections[race].default, gender)
    end

    for speechCollectionKey, speechCollectionTable in pairs(speechCollections[race]) do
        if speechCollectionKey ~= 'default' then
            tableHelper.insertValues(
                validList,
                speechHelper.GetPrintableValidListForSpeechCollection(
                    speechCollectionTable,
                    gender,
                    speechCollectionKey .. '_'
                )
            )
        end
    end

    return tableHelper.concatenateFromIndex(validList, 1, ', ')
end

--- Given a pid, a path to a speech collection, and an index to it, attempt to play that speech for all players
--- Returns whether or not the speech was found and played when called
---@param pid PlayerId
---@param speechInput string
---@param speechIndex integer
function speechHelper.PlaySpeech(pid, speechInput, speechIndex)
    local speechPath = speechHelper.GetSpeechPath(pid, speechInput, speechIndex)

    if not speechPath then return false end

    tes3mp.PlaySpeech(pid, speechPath)
    return true
end

---@type TES3MPScriptRegistration
return {
    interfaceName = 'speechHelper',
    -- FIXME: Define an interface function to allow defining/overriding speech collections
    interface = speechHelper,
}
