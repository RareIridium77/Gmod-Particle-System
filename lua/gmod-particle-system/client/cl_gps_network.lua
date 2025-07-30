GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local wind = GParticleSystem.__internal.wind

local gparticle = include("gparticle.lua")

local maxEmittersCvar = CreateConVar("cl_gparticle.max.emitters", "256", FCVAR_ARCHIVE, "Max allowed emitters at once", 1, 512)
local updateRateCvar = CreateConVar("cl_gparticle.rate", "15", FCVAR_ARCHIVE, "GParticleSystem update rate (fps)", 1, 60)
local showDebug = CreateClientConVar("cl_gparticle.debugoverlay", "1", true, false, "Show GParticleSystem debug overlay")

local activeEmitters = {}
local allParticles = {}
local nextThinkTime = 0

local function emitFromData(gp)
    if #activeEmitters >= maxEmittersCvar:GetInt() then return end

    local id = gp:GetParticleID()
    if not id or not GParticleSystem.CyclicFuncs[id] then return end

    local emitter = ParticleEmitter(gp:GetPos(), gp:GetUse3D())
    if not emitter then return end

    table.insert(activeEmitters, {
        gp = gp,
        count = gp:GetCount(),
        current = 0,
        emitRate = gp:GetEmitRate() or 0,
        nextEmit = CurTime(),
        emitter = emitter,
        entID = gp:GetEntityID() or nil,
        repeatsLeft = gp:GetRepeatCount() or 0,
    })
end

local function safeRemoveEmitter(i)
    local job = activeEmitters[i]
    if not job then return end

    if job.emitter and isfunction(job.emitter.Finish) then
        job.emitter:Finish()
    end

    local shouldRepeat = job.repeatsLeft and job.repeatsLeft > 0
    local delay = job.gp:GetRepeatDelay() or 0

    table.remove(activeEmitters, i)

    if shouldRepeat then
        job.repeatsLeft = job.repeatsLeft - 1
        job.gp:SetRepeatCount(job.repeatsLeft)

        if delay <= 0 then
            emitFromData(job.gp)
        else
            timer.Simple(delay, function()
                emitFromData(job.gp)
            end)
        end
    end
end

local function doJob(p, job, indexOverride)
    local gp = job.gp
    local pos = gp:GetPos()

    local entID = gp:GetEntityID()
    if entID and entID > 0 then
        local ent = Entity(entID)
        if not IsValid(ent) then
            gp:SetEntityID(nil)
            return
        else
            local maxs = ent:OBBMaxs().z * 0.5
            pos = ent:GetPos() + ent:GetUp() * maxs
            p:SetVelocityScale(true)
        end
    end

    p:SetPos(pos)

    local lifetime = gp:GetLifetime()
    if lifetime and lifetime > 0 then
        p:SetDieTime(lifetime)
    end

    local id = gp:GetParticleID()
    local cycleFunc = GParticleSystem.CyclicFuncs[id]
    if cycleFunc then
        local i = indexOverride or job.current
        local success, err = pcall(cycleFunc, p, i, gp)
        if not success then
            ErrorNoHaltWithStack("[GParticleSystem] Cycle error for '" .. tostring(id) .. "': " .. tostring(err))
        end
    end

    wind:ApplyWindToParticle(p, 1, 1, i)

    table.insert(allParticles, p)
end

hook.Add("Think", "GParticleSystem.EmitStepwise", function()
    if CurTime() < nextThinkTime then return end
    nextThinkTime = CurTime() + (1 / updateRateCvar:GetFloat())

    for i = #activeEmitters, 1, -1 do
        local job = activeEmitters[i]
        local gp = job.gp
        local emitter = job.emitter

        if not IsValid(emitter) then
            safeRemoveEmitter(i)
            continue
        end

        if gp.emitRate <= 0 then
            for j = 1, job.count do
                local pos = gp:GetPos()
                local p = emitter:Add(gp:GetEffectName(), pos)
                if not p then break end

                local ok = hook.Run("gparticle.PreEmit", p, j, gp)
                if ok ~= false then
                    doJob(p, job, j)
                end
                hook.Run("gparticle.PostEmit", p, j, gp)
            end
            safeRemoveEmitter(i)
        elseif CurTime() >= job.nextEmit then
            job.current = job.current + 1
            job.nextEmit = CurTime() + gp.emitRate

            local p = emitter:Add(gp:GetEffectName(), gp:GetPos())
            if p then
                local ok = hook.Run("gparticle.PreEmit", p, job.current, gp)
                if ok ~= false then
                    doJob(p, job, job.current)
                end
                hook.Run("gparticle.PostEmit", p, job.current, gp)
            end

            if job.current >= job.count then
                safeRemoveEmitter(i)
            end
        end
        
        for i = #allParticles, 1, -1 do
            local p = allParticles[i]

            if not IsValid(p) then
                table.remove(allParticles, i)
            end
        end
    end
end)

local function emit()
    local gp = gparticle.ReadFromNet()
    emitFromData(gp)
end

local function clear()
    for i = #activeEmitters, 1, -1 do
        safeRemoveEmitter(i)
    end
    for _, p in ipairs(allParticles) do
        if IsValid(p) then
            p:SetThinkFunction(nil)
            p:SetDieTime(0)
        end
    end
    table.Empty(allParticles)
end

net.Receive("gparticle.emit", emit)
net.Receive("gparticle.clear", clear)
concommand.Add("gparticle.clear", clear)

hook.Add("EntityRemoved", "GParticleSystem.ClearOnEntityRemove", function(ent)
    if not IsValid(ent) then return end
    local entID = ent:EntIndex()
    for i = #activeEmitters, 1, -1 do
        local job = activeEmitters[i]
        if job.entID == entID then
            safeRemoveEmitter(i)
        end
    end
end)

hook.Add("HUDPaint", "GParticleSystem.DebugOverlay", function()
    if not showDebug:GetBool() then return end

    local draw = draw
    local scrW, scrH = ScrW(), ScrH()
    local x, y = 16, scrH * 0.25

    surface.SetFont("DermaDefault")
    draw.SimpleText("[GParticleSystem Debug]", "DermaDefaultBold", x, y, color_white)
    y = y + 16

    draw.SimpleText("Active Emitters: " .. #activeEmitters, "DermaDefault", x, y, color_white)
    y = y + 14
    draw.SimpleText("Active Particles: " .. #allParticles, "DermaDefault", x, y, color_white)
    y = y + 14
    draw.SimpleText("Update Rate: " .. updateRateCvar:GetFloat() .. " fps", "DermaDefault", x, y, color_white)
    y = y + 14

    if wind and wind.GetWindVelocity then
        local vel = wind:GetWindVelocity() or vector_origin
        draw.SimpleText(string.format("Wind Velocity: %.1f %.1f %.1f", vel.x, vel.y, vel.z), "DermaDefault", x, y, color_white)
        y = y + 14
    end

    if wind and wind.GetWindTurbulence then
        local turb = wind:GetWindTurbulence() or 0
        draw.SimpleText("Wind Turbulence: " .. turb, "DermaDefault", x, y, color_white)
        y = y + 14
    end

    y = y + 8
    draw.SimpleText("Emitters Detail:", "DermaDefaultBold", x, y, Color(255, 200, 200))
    y = y + 16

    for i, job in ipairs(activeEmitters) do
        if y > scrH - 80 then
            draw.SimpleText("... (truncated)", "DermaDefault", x, y, Color(180, 180, 180))
            break
        end

        local gp = job.gp
        local name = tostring(gp:GetParticleID())
        local entInfo = job.entID and ("Entity[" .. job.entID .. "]") or "World"
        local repeatInfo = job.repeatsLeft and (" (" .. job.repeatsLeft .. " repeats left)") or ""
        local full = string.format("[%02d] %s @ %s%s", i, name, entInfo, repeatInfo)

        draw.SimpleText(full, "DermaDefault", x + 8, y, Color(200, 220, 255))
        y = y + 14

        local subinfo = string.format("    Count: %d | Current: %d | EmitRate: %.2f", job.count, job.current, gp:GetEmitRate() or 0)
        draw.SimpleText(subinfo, "DermaDefault", x + 8, y, Color(180, 255, 180))
        y = y + 12
    end
end)