local params = {...}

local verbose_suka = true

local last_param
for i, param in ipairs(params) do
	local param_name = param:match("^[-/]+(%C+)$") -- matches for common flag initializers, which are "/", "-" and "--" and captures flag name, if possible.

	if param_name then
		params[param_name] = true
		last_param = param_name
	elseif last_param then
		params[last_param] = tonumber(param) or param
		last_param = nil
	else
		print("Invalid command, incorrect flag pass near: " .. param)
		os.exit()
	end
end

if not params["output"] then
	params["output"] = "encoded"
end

-- Config

--#region Group configs

local groups = {
	-- Promo videos, new character, new location showcases
	{"^mv_prm142%.mp4", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -vf scale=-1:540 -an -crf 28 -preset %s -tune film -n \"%s\""},
	{"^mv_prm", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -an -crf 28 -preset %s -tune film -n \"%s\""},

	-- Event trailers
	{"^mv103_", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},
	{"^mv", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -vf scale=-1:720 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},

	-- Cutscenes (slightly better sound)
	{"^mm01011403", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},
	{"^mm03010105", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},
	{"^mm03010106", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},
	{"^mm03010107", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},
	{"^mm02010805_en", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 192k -crf 26 -preset %s -tune film -n \"%s\""},

	-- Cutscenes (remaining)
	{"^mm", "ffmpeg -i \"%s\" -filter:v fps=fps=30 -c:a aac -b:a 128k -crf 26 -preset %s -tune film -n \"%s\""},
}

--#endregion

-- OS detection

local OS

if package.config:sub(1,1) == "/" then
	OS = "posix"
else
	OS = "win32"
end

-- Create output directory

local output = params["output"]

if OS == "win32" then
	os.execute(string.format("if not exist \"%s\" mkdir \"%s\"", output, output))
elseif OS == "posix" then
	os.execute(string.format("mkdir -p \"%s\"", output))
end

--#region functions

local function available(name)
	if params["skip-checks"] then
		return "yes"
	end

	local h, err

	if OS == "win32" then
		h, err = io.popen("where " .. name)
	else
		h, err = io.popen("which " .. name)
	end

	if h then
		local result = h:read("*a")
		h:close()

		if result:find(name) then
			return result
		else
			return false
		end
	end

	error("Error checking ffmpeg installation! Err: " .. tostring(err) .. "\nPass flag --skip-checks for a failsafe.")
end

local function enumerate_mp4(path)
	path = path or ""

	local files = {}

	local h, err

	if OS == "win32" then
		h, err = io.popen("dir /b \"" .. path .. "\"")
	else
		h, err = io.popen("ls -1 \"" .. path .. "\"")
	end

	if h then
		local filenames = h:read("*a")
		h:close()

		for file in string.gmatch(filenames, "%C+%.mp4") do
			files[#files+1] = file
		end

		return files
	end

	error("Error enumerating films. Err: " .. tostring(err))
end

local function filter_korean(videos)
	for i = #videos, 1, -1 do
		local video = videos[i]

		if video:find("ko") then
			table.remove(videos, i)
		end
	end
end

--#endregion

-- Init

print("Nier:reiN video compression utility")

local ffmpeg = available("ffmpeg")

if not ffmpeg then
	print("You do not have ffmpeg installed! Please install ffmpeg or open a new console if you recently added it to PATH.")
	return
end

print("Found ffmpeg at " .. ffmpeg)

local videos = enumerate_mp4(params["input"])

print("Found " .. #videos .. " videos.")

if #videos == 0 then
	if params["input"] then
		print("No videos were found in provided input folder. Check again your \"--input\" parameter.")
	else
		print("No videos were found in working directory. Have you forgot to pass the \"--input\" parameter?")
	end
end

-- Skip Koreans

local choice
repeat
	io.write("Skip Korean language videos (Recoding will be 40% faster)? Y/N [Default: Y]: ")
	choice = string.lower(io.read())
until choice == "y" or choice == "t" or choice == "n" or choice == "f" or choice == ""

if #choice == 0 then
	choice = "y"
end

local skip_korean = choice == "y" or choice == "t" or false

if skip_korean then
	local old_count = #videos

	filter_korean(videos)
	print(string.format("Skipping Korean language films. Now processing %d videos instead of %d.", #videos, old_count))
else
	print(string.format("Processing all %d videos.", #videos))
end

-- Preset logic

local presets = {
	"ultrafast",
	"superfast",
	"veryfast",
	"faster",
	"fast",
	"medium",
	"slow",
	"slower",
	"veryslow",
	"placebo"
}
for i, preset in ipairs(presets) do
	presets[preset] = i
end

local function printPresets()
	print("")

	for i, preset in ipairs(presets) do
		print(i .. ". " .. preset)
	end
	print("(never pick placebo)")
end

repeat
	printPresets()

	print("\nSelect an ffmpeg preset which will be used. Preset affects video size, quality and encoding time.")
	print("From \"ultrafast\" (worst file size, fastest encoding) to \"veryslow\" (best file size, slowest encoding)")
	print("Default preset is \"medium\" (6), \"slower\" (8) provides a 5% filesize difference but is recommended on better systems.")
	io.write("Select preset (number or full name) [Default: 6]: ")

	choice = string.lower(io.read())
	choice = choice == "" and presets[6] or choice
	choice = tonumber(choice) and presets[tonumber(choice)] or choice
until presets[choice]

print(string.format("\nSelected preset: %s (%d)", choice, presets[choice]))
local preset = choice

-- Start encoding
local pattern_stats = {}
local skip_pattern = "skip"

local input_folder = params["input"]
if input_folder then
	input_folder = input_folder .. "/"
else
	input_folder = ""
end

local output_folder = output .. "/"

for _, file in ipairs(videos) do
	local matched = false

	for i, group in pairs(groups) do
		local pattern, command = group[1], group[2]

		if file:match(pattern) then
			pattern_stats[i] = pattern_stats[i] or {}
			pattern_stats[i][#pattern_stats[i]+1] = file

			os.execute(string.format(command, input_folder .. file, preset, output_folder .. file))

			matched = true
			break
		end
	end

	if not matched then
		pattern_stats[skip_pattern] = pattern_stats[skip_pattern] or {}
		pattern_stats[skip_pattern][#pattern_stats[skip_pattern]+1] = file
	end
end

if params["v"] or params["verbose"] or verbose_suka then
	print("\nPattern statistics:")
	local i = 1
	for pattern, files in pairs(pattern_stats) do
		if pattern ~= skip_pattern then
			print("")
			print(i .. ". [".. #files .." files] Command: " .. string.format(groups[pattern][2], "input_file", preset, "output_file"))
			print(table.concat(files, ", "))

			i = i + 1
		end
	end

	if pattern_stats[skip_pattern] then
		print("")
		print(i .. ". [" .. #pattern_stats[skip_pattern] .. (skip_korean and "+" or "") .. " files] Skipped recoding")

		if skip_korean then
			io.write("All korean movies, ")
		end

		print(table.concat(pattern_stats[skip_pattern]))
	end
end




print("\nRecoding finished! Processed " .. (#videos - #(pattern_stats[skip_pattern] or {})) .. " files out of " .. #videos .. ".")