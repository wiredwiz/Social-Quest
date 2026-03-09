-- Author      : Thad
-- Create Date : 11/20/2008 8:24:33 PM

-- This function is a slightly modified version of Titan Panel's TitanUtils_GetColoredText function so I can't take any credit for it
function GetColorCode(color)
	if (color) then
		local redColorCode = format("%02x", color.r * 255);		
		local greenColorCode = format("%02x", color.g * 255);
		local blueColorCode = format("%02x", color.b * 255);		
		local colorCode = "|cff"..redColorCode..greenColorCode..blueColorCode;
		return colorCode;
	end
end

-- Now we define all our extra font colors as long as they don't exist already
if not getglobal("WHITE_FONT_COLOR") then		WHITE_FONT_COLOR = {r=1,g=1,b=1};				end
if not getglobal("YELLOW_FONT_COLOR") then		YELLOW_FONT_COLOR = {r=1,g=1,b=.1};				end
if not getglobal("BLUE_FONT_COLOR") then		BLUE_FONT_COLOR = {r=0,g=0,b=1};				end
if not getglobal("PURPLE_FONT_COLOR") then		PURPLE_FONT_COLOR = {r=.63,g=.13,b=.94};		end
if not getglobal("ROYALBLUE_FONT_COLOR") then	ROYALBLUE_FONT_COLOR = {r=.25,g=.41,b=1}		end
if not getglobal("ORANGE_FONT_COLOR") then		ORANGE_FONT_COLOR = {r=1,g=.49,b=0}				end
if not getglobal("TEAL_FONT_COLOR") then		TEAL_FONT_COLOR = {r=0,g=1,b=.60}				end
if not getglobal("GOLD_FONT_COLOR") then		GOLD_FONT_COLOR = {r=1,g=.84,b=0}				end


-- Now the same drill for our font color codes
if not getglobal("WHITE_FONT_COLOR_CODE") then		WHITE_FONT_COLOR_CODE = GetColorCode(WHITE_FONT_COLOR)			end
if not getglobal("YELLOW_FONT_COLOR_CODE") then		YELLOW_FONT_COLOR_CODE = GetColorCode(YELLOW_FONT_COLOR)		end
if not getglobal("BLUE_FONT_COLOR_CODE") then		BLUE_FONT_COLOR_CODE = GetColorCode(BLUE_FONT_COLOR)			end
if not getglobal("PURPLE_FONT_COLOR_CODE") then		PURPLE_FONT_COLOR_CODE = GetColorCode(PURPLE_FONT_COLOR)		end
if not getglobal("ROYALBLUE_FONT_COLOR_CODE") then	ROYALBLUE_FONT_COLOR_CODE = GetColorCode(ROYALBLUE_FONT_COLOR)	end
if not getglobal("ORANGE_FONT_COLOR_CODE") then		ORANGE_FONT_COLOR_CODE = GetColorCode(ORANGE_FONT_COLOR)		end
if not getglobal("TEAL_FONT_COLOR_CODE") then		TEAL_FONT_COLOR_CODE = GetColorCode(TEAL_FONT_COLOR)			end
if not getglobal("GOLD_FONT_COLOR_CODE") then		GOLD_FONT_COLOR_CODE = GetColorCode(GOLD_FONT_COLOR)			end