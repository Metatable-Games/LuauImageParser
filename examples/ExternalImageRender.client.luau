-- EditableImages do not replicate; so render it on the client.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImageParser = require(ReplicatedStorage.ImageParser)

local function ExternalImageAdded(ImageLabel: ImageLabel)
	local imageUrl = ImageLabel:GetAttribute("ExternalImageURL") or nil;
	local imageSize = ImageLabel:GetAttribute("ExternalImageSize") or 512;

	if not imageUrl then
		return;
	end

	local EditableImage: EditableImage? = ImageParser:ParseImageToEditableImage(imageUrl, imageSize)

	if EditableImage then
		ImageLabel.ImageContent = Content.fromObject(EditableImage)
	else
		local ImageError = Instance.new("TextLabel")
		ImageError.BackgroundColor3 = Color3.new(0.588235, 0.094117, 0.094117)
		ImageError.Text = "Image or drawing failed to render.."
		ImageError.TextScaled = true
		ImageError.Size = UDim2.new(1, 0, 1, 0)
		ImageError.Parent = ImageLabel
	end
end

CollectionService:GetInstanceAddedSignal("ExternalImage"):Connect(ExternalImageAdded)

for _, ImageLabel in ipairs(CollectionService:GetTagged("ExternalImage")) do
	task.spawn(ExternalImageAdded, ImageLabel)
end
