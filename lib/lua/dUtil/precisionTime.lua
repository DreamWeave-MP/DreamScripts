local ffi, osType = require 'ffi', tes3mp.GetOperatingSystemType()

local MSSinceStart = tes3mp.GetMillisecondsSinceServerStart

local PlatformHandlers = {
  Linux = function()
    ffi.cdef [[
        typedef long time_t;
        typedef int clockid_t;

        struct timespec {
            time_t tv_sec;
            long   tv_nsec;
        };

        int clock_gettime(clockid_t clk_id, struct timespec *tp);
    ]]

    local CLOCK_MONOTONIC = 1
    local ts = ffi.new("struct timespec[1]")
    local NANOSECONDS_PER_SECOND_MULT = 1.0 / 1e9

    return function()
      if ffi.C.clock_gettime(CLOCK_MONOTONIC, ts) ~= 0 then return MSSinceStart() / 1000. end

      return tonumber(ts[0].tv_sec) + (tonumber(ts[0].tv_nsec) * NANOSECONDS_PER_SECOND_MULT)
    end
  end,
  ['OS X'] = function()
    ffi.cdef [[
        typedef struct {
            uint32_t numer;
            uint32_t denom;
        } mach_timebase_info_data_t;

        uint64_t mach_absolute_time(void);
        int mach_timebase_info(mach_timebase_info_data_t* info);
    ]]

    local timebase = ffi.new("mach_timebase_info_data_t[1]")
    local timebaseInitialized = false
    local resolution = 0

    return function()
      if not timebaseInitialized then
        ffi.C.mach_timebase_info(timebase)
        resolution = tonumber(timebase[0].numer) / tonumber(timebase[0].denom)
        timebaseInitialized = true
      end

      return tonumber(ffi.C.mach_absolute_time()) * resolution * 1e-9
    end
  end,
  ['Unknown OS'] = function()
    return MSSinceStart() / 1000
  end,
  Windows = function()
    ffi.cdef [[
        typedef long long LARGE_INTEGER;

        int QueryPerformanceCounter(LARGE_INTEGER* lpPerformanceCount);
        int QueryPerformanceFrequency(LARGE_INTEGER* lpFrequency);
    ]]

    local counter, frequency, freqInitialized, multiplier = ffi.new("long long[1]"), ffi.new("long long[1]"), false, 0

    return function()
      if not freqInitialized then
        ffi.C.QueryPerformanceFrequency(frequency)
        multiplier = 1.0 / tonumber(frequency[0])
        freqInitialized = true
      end

      ffi.C.QueryPerformanceCounter(counter)
      return tonumber(counter[0]) * multiplier
    end
  end,
}

os.time = assert(PlatformHandlers[osType]())
