local fins = {}

local sqrt = math.sqrt
local setFont, getTextSize = surface.SetFont, surface.GetTextSize
local drawRoundedBoxEx, drawText, drawBeam = draw.RoundedBoxEx, draw.DrawText, render.DrawBeam
local drawSimpleTextOutlined = draw.SimpleTextOutlined
local setColorMaterialIgnoreZ = render.SetColorMaterialIgnoreZ
local camStart3D, camEnd3D = cam.Start3D, cam.End3D
local format = string.format
local allowedClasses, localToWorldVector = Fin3.allowedClasses, Fin3.localToWorldVector
local getPhrase = language.GetPhrase

net.Receive("fin3_networkfinids", function()
    for _ = 1, net.ReadUInt(10) do
        fins[net.ReadUInt(13)] = true
    end
end)

local cvarDebugEnabled = GetConVar("fin3_debug")
local cvarShowVectors = GetConVar("fin3_debug_showvectors")
local cvarShowForces = GetConVar("fin3_debug_showforces")

local RED, GREEN = Color(255, 0, 0), Color(0, 255, 0)
local BACKGROUND = Color(0, 0, 0, 230)

local function getForceString(newtons)
    local kgf = newtons / 15.24 -- GMod's gravity is 15.24m/s²

    if kgf < 1000 then
        return format("%dkg", kgf)
    else
        return format("%.2ft", kgf / 1000)
    end
end

local function drawDebugInfo()
    if not cvarDebugEnabled:GetBool() then return end

    local showVectors = cvarShowVectors:GetBool()
    local showForces = cvarShowForces:GetBool()

    if showVectors or showForces then
        for index in pairs(fins) do
            local fin = Entity(index)

            if not IsValid(fin) or fin:GetNW2String("fin3_finType") == "" then
                fins[index] = nil
            else
                local finPos = fin:LocalToWorld(fin:OBBCenter())

                if showVectors then
                    local liftVector = fin:GetNW2Vector("fin3_liftVector", vector_origin)
                    local dragVector = fin:GetNW2Vector("fin3_dragVector", vector_origin)

                    if liftVector ~= vector_origin or dragVector ~= vector_origin then
                        local liftLength = liftVector:Length()
                        local dragLength = dragVector:Length()

                        local scaledLiftVector = liftVector:GetNormalized() * sqrt(liftLength)
                        local scaledDragVector = dragVector:GetNormalized() * sqrt(dragLength)

                        camStart3D()
                            setColorMaterialIgnoreZ()
                            drawBeam(finPos, finPos + scaledLiftVector, 1, 0, 1, GREEN)
                            drawBeam(finPos, finPos + scaledDragVector, 1, 0, 1, RED)
                        camEnd3D()
                    end
                end

                if showForces and fin:GetPos():DistToSqr(LocalPlayer():GetPos()) < 400000 then
                    local screenPos = finPos:ToScreen()

                    local liftVector = fin:GetNW2Vector("fin3_liftVector", vector_origin)
                    local dragVector = fin:GetNW2Vector("fin3_dragVector", vector_origin)
                    local liftForceStr = getForceString(liftVector:Length())
                    local dragForceStr = getForceString(dragVector:Length())

                    local text = format("Lift: %s\nDrag: %s", liftForceStr, dragForceStr)
                    setFont("Trebuchet18")
                    local textWidth, textHeight = getTextSize(text)
                    textWidth = textWidth + 10
                    textHeight = textHeight + 10

                    drawRoundedBoxEx(8, screenPos.x - textWidth, screenPos.y - textHeight, textWidth, textHeight, BACKGROUND, true, true, true, false)
                    drawText(text, "Trebuchet18", screenPos.x - 5, screenPos.y - textHeight + 5, color_white, TEXT_ALIGN_RIGHT)
                end
            end
        end
    end
end

local function drawFin3Hud(localPly)
    local eyeTrace = localPly:GetEyeTrace()
    local selected = localPly:GetNW2Entity("fin3_selectedEntity")
    local ent = eyeTrace.Entity

    if IsValid(selected) then
        ent = selected
    end

    if not IsValid(ent) or not allowedClasses[ent:GetClass()] then return end

    local fin2Eff = ent:GetNWFloat("efficency", 0)
    if fin2Eff ~= 0 and fin2Eff ~= -99 and fin2Eff ~= -100000000 then
        local drawPos = ent:LocalToWorld(ent:OBBCenter()):ToScreen()
        drawSimpleTextOutlined("Warning: this entity still has Fin 2 applied!", "DermaLarge", drawPos.x, drawPos.y, RED, 1, 1, 1, color_black)
    end

    local tempUpAxis = localPly:GetNW2Vector("fin3_tempUpAxis", vector_origin)
    local tempForwardAxis = localPly:GetNW2Vector("fin3_tempForwardAxis", vector_origin)

    local centerPos = ent:LocalToWorld(ent:OBBCenter())
    local entSize = (ent:OBBMaxs() - ent:OBBMins()):Length() / 2

    if tempUpAxis ~= vector_origin then
        local worldTempUpAxis = localToWorldVector(ent, tempUpAxis)

        camStart3D()
            setColorMaterialIgnoreZ()
            drawBeam(centerPos, centerPos + worldTempUpAxis * 25, 0.5, 0, 1, GREEN)
        camEnd3D()

        local upTextPos = (centerPos + worldTempUpAxis * 25):ToScreen()
        drawSimpleTextOutlined("Lift Vector", "DermaLarge", upTextPos.x, upTextPos.y, GREEN, 1, 1, 1, color_black)
    end

    if tempForwardAxis ~= vector_origin then
        if tempForwardAxis ~= vector_origin and tempForwardAxis ~= tempUpAxis then
            local worldTempForwardAxis = localToWorldVector(ent, tempForwardAxis)

            camStart3D()
                setColorMaterialIgnoreZ()
                drawBeam(centerPos, centerPos + worldTempForwardAxis * entSize, 0.5, 0, 1, RED)
            camEnd3D()

            local fwdTextPos = (centerPos + worldTempForwardAxis * entSize):ToScreen()
            drawSimpleTextOutlined("Forward", "DermaLarge", fwdTextPos.x, fwdTextPos.y, RED, 1, 1, 1, color_black)
        else
            local invalidTextPos = centerPos:ToScreen()
            drawSimpleTextOutlined("Invalid Forward Vector", "DermaLarge", invalidTextPos.x, invalidTextPos.y, RED, 1, 1, 1, color_black)
        end
    end

    local finType = ent:GetNW2String("fin3_finType", "")

    if finType == "" then return end

    local setUpAxis = localToWorldVector(ent, ent:GetNW2Vector("fin3_upAxis", vector_origin))
    local setForwardAxis = localToWorldVector(ent, ent:GetNW2Vector("fin3_forwardAxis", vector_origin))
    local zeroLiftAngle = ent:GetNW2Float("fin3_zeroLiftAngle", 0)
    local efficiency = ent:GetNW2Float("fin3_efficiency", 0)
    local surfaceArea = ent:GetNW2Float("fin3_surfaceArea", 0)
    local aspectRatio = ent:GetNW2Float("fin3_aspectRatio", 0)
    local sweepAngle = ent:GetNW2Float("fin3_sweepAngle", 0)
    local inducedDrag = ent:GetNW2Float("fin3_inducedDrag", 0)
    local lowpass = ent:GetNW2Bool("fin3_lowpass", false)

    camStart3D()
        setColorMaterialIgnoreZ()
        drawBeam(centerPos, centerPos + setForwardAxis * entSize, 0.5, 0, 1, RED)
        drawBeam(centerPos, centerPos + setUpAxis * 25, 0.5, 0, 1, GREEN)
    camEnd3D()

    local fwdTextPos = (centerPos + setForwardAxis * entSize):ToScreen()
    drawSimpleTextOutlined("Forward", "DermaLarge", fwdTextPos.x, fwdTextPos.y, RED, 1, 1, 1, color_black)

    local upTextPos = (centerPos + setUpAxis * 25):ToScreen()
    drawSimpleTextOutlined("Lift Vector", "DermaLarge", upTextPos.x, upTextPos.y, GREEN, 1, 1, 1, color_black)

    setFont("Trebuchet18")
    local infoPos = centerPos:ToScreen()

    local text = format("Airfoil Type: %s\n%sEfficiency: %.2fx\nEffective Surface Area: %.2fm²\nAspect Ratio: %.2f\nInduced Drag: %.2fx",
        getPhrase("tool.fin3.fintype." .. finType),
        zeroLiftAngle ~= 0 and format("Zero Lift Angle: -%.1f°\n", zeroLiftAngle) or "",
        efficiency,
        surfaceArea * efficiency,
        aspectRatio,
        inducedDrag
    )

    if sweepAngle ~= 0 then
        text = text .. format("\nSweep Angle: %.1f°", sweepAngle)
    end

    if lowpass then
        text = text .. "\nLow-pass filter enabled"
    end

    local textWidth, textHeight = getTextSize(text)

    drawRoundedBoxEx(8, infoPos.x, infoPos.y, textWidth + 10, textHeight + 10, BACKGROUND, false, true, true, true)
    drawText(text, "Trebuchet18", infoPos.x + 5, infoPos.y + 5, color_white, TEXT_ALIGN_LEFT)
end

local function drawFin3PropellerHud(localPly)

end

hook.Add("HUDPaint", "fin3_hud", function()
    drawDebugInfo()

    local localPly = LocalPlayer()
    local wep = localPly:GetActiveWeapon()
    local toolmode = localPly:GetInfo("gmod_toolmode")

    if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return end

    if toolmode == "fin3" then
        drawFin3Hud(localPly)
    elseif toolmode == "fin3_propeller" then
        drawFin3PropellerHud(localPly)
    end
end)
