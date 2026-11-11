#    Transcribe_Speech_Form is a praat script to run speech transcription
#    on recordings and outpust the resulting text in several formats.
#    Copyright (C) 2026  R.J.J.H. van Son
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

clearinfo

# Read available ASR models.
modelList$# = fileNames$#(preferencesDirectory$+"/models/whispercpp/*")

form: "Transcribe a speech recording directly to text"
		comment: "A simple interface for creating text(Grid) files direxctly from speech recordings."
		comment: "Can output subtitle (.srt) and plain text (.txt) files as well as full TextGrids."

		comment: "                                    Language name, eg., ""Dutch"", or code, eg., ""nl"" "
		word: "Language", "nl"
		
		natural: "Number of speakers", "2"
		
		sentence: "Choose a model:", "(keep empty to select a model)"
		
		comment: "                 Transcribe a single file (checked) or all files in a folder (unchecked)"
		boolean: "Transcribe single file", 1
		sentence: "Input recording or folder", "(keep empty to select a file or folder)"
		sentence: "Output folder", "(keep empty to select a folder)"
		
		optionmenu: "Output format", 2
			option: "Textgrid"
			option: "Subtitle (.srt)"
			option: "Plain text (.txt)"
endform

# Output file type
output_file_type$ = "TextGrid"
if startsWith(output_format$, "Subtitle")
	output_file_type$ = "srt"
elsif startsWith(output_format$, "Plain")
	output_file_type$ = "txt"
endif

# Select the model if it is not given
choose_a_model$ = replace_regex$(choose_a_model$, "\s*\(keep empty to select a model\)\s*", "", 0)
if not index_regex(choose_a_model$, "\S")

	modelChoice$ = ""
	writeInfoLine: "Available models. Select one"
	for .s to size (modelList$#)
		modelChoice$ = modelChoice$ + string$(.s) + ": " + modelList$#[.s] + "; "
		appendInfoLine: string$(.s) + ": " + modelList$#[.s]
	endfor
	
	beginPause: "Transcribe Speech"
		comment: "Available models:"
		comment: modelChoice$
		comment: " "
		positive: "Choose a model:", 1
	modelClicked = endPause: "Cancel", "Continue", 2, 1
	
	if modelClicked = 1
		goto FINISHED
	endif
	
	modelChosen$ = modelList$# [choose_a_model]
else
	modelChosen$ = "ggml-tiny-q5_1.bin"
endif

# Get input recording files
input_folder$ = ""
input_recording_or_folder$ = replace_regex$(input_recording_or_folder$, "\s*\(keep empty to select a file or folder\)\s*", "", 0)
recordingList$# = empty$#(1)
if transcribe_single_file
	if index_regex(input_recording_or_folder$, "\S")
		recordingList$# = {input_recording_or_folder$}
	else
		pauseScript: "Open the recording audio to be transcribed"
		audioName$ = chooseReadFile$: "Open a speech file"
		recordingList$# = {audioName$}
	endif
else
	if index_regex(input_recording_or_folder$, "\S")
		input_folder$ = input_recording_or_folder
	else
		pauseScript: "Select folder with the recording audio files to be transcribed"
		input_folder$ = chooseFolder$( "Choose an input folder with audio recordings")
	endif
	if index_regex(input_folder$, "\S")
		recordingList$# = fileNames$#(input_folder$)
		for .fn to size (recordingList$#)
			recordingList$#[.fn] = input_folder$ + "/" + recordingList$#[.fn]
		endfor
	endif
endif

# Select an output folder if none is given and but there are recording files to be transcribed
if index_regex(recordingList$#[1], "\S")
	output_folder$ = replace_regex$(output_folder$, "\s*\(keep empty to select a folder\)\s*", "", 0)
	if output_folder$ = ""
		pauseScript: "Select the folder to write the transcription file"
		output_folder$ = chooseFolder$( "Choose an output folder for the transcript")
	endif
else
	goto FINISHED
endif

# Erase the info window
clearinfo
# Set the model parameters
.include_words$ = "no"
if output_file_type$ = "TextGrid"
	.include_words$ = "yes"
endif
.include_diarization$ = "yes"
if number_of_speakers < 2
	.include_diarization$ = "no"
	number_of_speakers = 2
endif

# Iterate over all input files
for .f to size (recordingList$#)
	audioName$ = recordingList$#[.f]
	if index_regex(audioName$, "\S")
		# Check whether this is an audio file
		if not index_regex(audioName$, "\.(?iwav|mp3|flac|aif|aiff|aifc|ogg|au|opus)$")
			goto NEXTRECORDING
		endif
		
		# Create output filename
		outputFileName$ = replace_regex$(audioName$, "\.[^\.]+$", "." + output_file_type$, 1)
		if index_regex(output_folder$, "\S")
			fileName$ = replace_regex$(outputFileName$, "^.*[/\\]([^/\\]+)$", "\1", 0 )
			outputFileName$ = replace_regex$(output_folder$ + "/" + fileName$, "//+", "/", 0)
		endif
		
		if fileReadable(outputFileName$)
			goto NEXTRECORDING
		endif

		# Transcribe
		
		recording = Read from file: audioName$
		textGrid = To TextGrid: "IPU", ""
		selectObject: recording
		plusObject: textGrid
		nowarn Transcribe interval: 1, 1, modelChosen$, language$, .include_words$, "yes", 0.5, 0.1, 0.25, 0, .include_diarization$, number_of_speakers, "yes", 0.7, 0.1
		
		if output_file_type$ = "txt"
			selectObject: textGrid
			numIPU = Get number of intervals: 1
			.subtitleCount = 0
			for .i to numIPU
				selectObject: textGrid
				.currentInt$ = Get label of interval: 1, .i
				if index_regex(.currentInt$, "\S")
					appendInfoLine: .currentInt$
					appendFileLine: outputFileName$, .currentInt$
				endif
			endfor

		elsif output_file_type$ = "srt"
			writeFileLine: outputFileName$, ""
			selectObject: textGrid
			numIPU = Get number of intervals: 1
			.subtitleCount = 0
			for .i to numIPU
				selectObject: textGrid
				.currentInt$ = Get label of interval: 1, .i
				if index_regex(.currentInt$, "\S")
					.start = Get start time of interval: 1, .i
					@sec2hours: .start
					.startTime$ = sec2hours.time$
					.end = Get end time of interval: 1, .i
					@sec2hours: .end
					.endTime$ = sec2hours.time$
					
					.subtitleCount += 1
					# Info
					appendInfoLine: .subtitleCount
					appendInfoLine: .startTime$, " --> ", .endTime$
					appendInfoLine: .currentInt$
					appendInfoLine: ""
					
					# Output File
					appendFileLine: outputFileName$, .subtitleCount
					appendFileLine: outputFileName$, .startTime$, " --> ", .endTime$
					appendFileLine: outputFileName$, .currentInt$
					appendFileLine: outputFileName$, ""
					
				endif
			endfor
		
		else
				selectObject: textGrid
				Save as short text file: outputFileName$
		endif

		selectObject: recording
		plusObject: textGrid
		Remove
	endif
	
	label NEXTRECORDING
endfor

# Finished
label FINISHED

procedure sec2hours: .seconds
	.tmp = .seconds
	.hours = .tmp div (60*60)
	.tmp -= .hours * (60*60)
	.minutes = .tmp div 60
	.tmp -= .minutes * 60
	.seconds = floor(.tmp)
	.tmp -= .seconds
	.millisec = floor(1000 * .tmp)
	
	.time$ = padLeft$( string$(.hours), 2, "0") + ":" + padLeft$( string$(.minutes), 2, "0") + ":" + padLeft$( string$(.seconds), 2, "0") + "," + padLeft$( string$(.millisec), 3, "0")
	
endproc
