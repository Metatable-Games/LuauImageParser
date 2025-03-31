--!strict

-- (c) 2025 metatable.dev, all rights reserved.
-- Strict Luau module for drawing API-based pixel data to EditableImage using WritePixelsBuffer

local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local DEBUG = false
local API_URL = DEBUG and "http://127.0.0.1:8787" or "https://image-parser.tyrannizerdev.workers.dev"

export type RGB = { number }
export type PixelMatrix = { [number]: { [number]: RGB } }

export type PixelMatrixResponse = {
	width: number,
	height: number,
	pixels: PixelMatrix,
}

local ImageParser = {}
ImageParser.__index = ImageParser

function ImageParser.new()
	local self = setmetatable({}, ImageParser)

	if RunService:IsClient() then
		warn("[ImageParser] This module should not be inited on the client.")
		return nil
	end

	local RemoteFunction = script:FindFirstChildOfClass("RemoteFunction") or Instance.new("RemoteFunction", script)

	RemoteFunction.OnServerInvoke = function(player: Player, action: string, ...)
		local args = {...};

		if action == "GetPixelMatrix" then
			-- Handle the request for pixel matrix data from the client
			if #args < 1 then
				warn("[ImageParser] Invalid arguments for GetPixelMatrix")
				return nil
			end

			local imageUrl = args[1] :: string
			local resize = args[2] :: number?

			-- Call the method to get the pixel matrix from the image URL
			return self:GetPixelMatrix(imageUrl, resize)
		else
			warn("[ImageParser] Unknown action:", action)
			return nil
		end
	end

	return self
end

function ImageParser:GetPixelMatrix(imageUrl: string, resize: number?): PixelMatrixResponse?
	assert(typeof(imageUrl) == "string" and imageUrl ~= "", "Invalid image URL")

	if RunService:IsClient() then
		if not script:FindFirstChildOfClass("RemoteFunction") then
			repeat
				task.wait(.1)
			until script:FindFirstChildOfClass("RemoteFunction")
		end

		return script:FindFirstChildOfClass("RemoteFunction"):InvokeServer("GetPixelMatrix", imageUrl, resize)
	end

	local encodedUrl = HttpService:UrlEncode(imageUrl)
	local url = API_URL .. "/?url=" .. encodedUrl

	if resize then
		url ..= "&resize=" .. tostring(resize)
	end

	local success, result = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET"
		})
	end)

	if not success or not result.Success then
		warn("[ImageParser] Request failed:", result)
		return nil
	end

	if result.StatusCode ~= 200 then
		warn(("[ImageParser] Failed to fetch from API: HTTP %d (%s)"):format(result.StatusCode, result.StatusMessage))
		warn("[ImageParser] Body:", result.Body)
		return nil
	end

	local ok, data = pcall(HttpService.JSONDecode, HttpService, result.Body)

	if not ok then
		warn("[ImageParser] JSON decode failed:", data)
		return nil
	end

	if typeof(data) ~= "table" or typeof(data.width) ~= "number" or typeof(data.height) ~= "number" or typeof(data.pixels) ~= "table" then
		warn("[ImageParser] Malformed API response")
		return nil
	end

	return data :: PixelMatrixResponse
end

function ImageParser:CreateEditableImageFromMatrix(matrixData: PixelMatrixResponse)
	assert(matrixData.width and matrixData.height and matrixData.pixels, "Invalid matrix data")

	local width = matrixData.width
	local height = matrixData.height
	local pixels = matrixData.pixels

	local editableImage = AssetService:CreateEditableImage({
		Size = Vector2.new(width, height)
	})

	local bufferSize = width * height * 4 -- RGBA (4 bytes per pixel)
	local pixelBuffer = buffer.create(bufferSize)

	local bufferIndex = 0
	for y = 1, height do
		for x = 1, width do
			local pixel = pixels[y][x]
			buffer.writeu8(pixelBuffer, bufferIndex, pixel[1]) -- R
			buffer.writeu8(pixelBuffer, bufferIndex + 1, pixel[2]) -- G
			buffer.writeu8(pixelBuffer, bufferIndex + 2, pixel[3]) -- B
			buffer.writeu8(pixelBuffer, bufferIndex + 3, 255) -- Alpha (opaque)
			bufferIndex += 4
		end
	end

	editableImage:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(width, height), pixelBuffer)

	return editableImage
end

function ImageParser:ParseImageToEditableImage(imageUrl: string, resize: number?)
	local matrixData = self:GetPixelMatrix(imageUrl, resize)
	if not matrixData then
		warn("[ImageParser] Could not get pixel matrix data.")
		return nil
	end
	return self:CreateEditableImageFromMatrix(matrixData)
end

return ImageParser
