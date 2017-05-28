local ffi = require'ffi'
local tonumber = tonumber
local M = {}
return function(M)
	if ffi.os == 'Windows' then
		ffi.cdef[[
		typedef struct _FILETIME {
		  int dwLowDateTime;
		  int dwHighDateTime;
		} FILETIME;
		void GetSystemTimeAsFileTime(
			FILETIME* lpSystemTimeAsFileTime
		);
		void Sleep(int dwMillis);
		]]
		local rt = ffi.new('FILETIME[1]')
		local lp = ffi.new('uint64_t[1]')
		function M.getTime()
			ffi.C.GetSystemTimeAsFileTime(rt)
			local low = 0ULL + rt[0].dwLowDateTime
			local hi = 0ULL + rt[0].dwHighDateTime
			local nanos = bit.bor( bit.lshift(hi, 32), low )
				 --[[Unix Epoch - Windows Epoch, in milliseconds]]
			return tonumber(nanos/1000-116444736000000ULL)/10000
		end
		local nt = ffi.load'ntdll'
		function M.sleepReal(seconds)
			ffi.C.Sleep(seconds/1000)
		end
	elseif ffi.os == 'Linux' then
		ffi.cdef[[
			typedef long time_t;
			typedef struct timeval {
				time_t tv_sec;
				time_t tv_usec;
			} timeval;
			int gettimeofday(timeval*, void*);
			void nanosleep(timeval*, timeval*)
		]]
		local tv = ffi.new('timeval[1]')
		function M.getTime()
			ffi.C.gettimeofday(tv, nil)
			return tonumber(tv[0].tv_sec) + tonumber(tv[0].tv_usec)/100000
		end
		function M.sleepReal(seconds)--While I wouldn't recommend using timeval for this, they're the same struct definition post type-resolve, so it shouldn't matter.
			tv[0].tv_sec = floor(seconds)
			tv[0].tv_usec = (seconds - floor(seconds)) * 1000000LL
			ffi.C.nanosleep(tv, nil)
		end
	end
end
