-- GParticleSystem Client Rewrite

GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local gparticle = include("gparticle.lua")

local maxEmittersCvar = CreateConVar("cl_gparticle_max_emitters", "128", FCVAR_ARCHIVE, "Max allowed emitters at once", 1, 256)

local activeEmitters = {}
local allParticles = {}

local function safeRemoveEmitter(i)
    local job = activeEmitters[i]
    if job then
        if job.emitter and isfunction(job.emitter.Finish) then
            job.emitter:Finish()
        end
        job.gp = nil
        job.entID = nil
    end
    table.remove(activeEmitters, i)
end

local function doJob(p, job)
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

    local wind = gp:GetWind() or vector_origin
    if wind ~= vector_origin then
        local windDragForce = wind * 0.1
        local dragAdd = windDragForce * 0.015

        p:SetNextThink(CurTime())
        p:SetThinkFunction(function(pa)
            local turb = gp:GetWindTurbulence() or 0
            local randomTurbulence = VectorRand() * (0.1 * turb)
            pa:SetGravity(pa:GetGravity() + dragAdd + randomTurbulence)
            pa:SetNextThink(CurTime() + 0.015)
        end)
    end

    p:SetVelocity(gp:GetVelocity() * gp:GetSpeed())
    p:SetGravity(gp:GetGravity())
    p:SetDieTime(gp:GetLifetime())
    p:SetStartAlpha(gp:GetStartAlpha())
    p:SetEndAlpha(gp:GetEndAlpha())
    p:SetStartSize(gp:GetStartSize())
    p:SetEndSize(gp:GetEndSize())
    p:SetColor(unpack(gp:GetColor()))
    p:SetRoll(gp:GetRoll())
    p:SetRollDelta(gp:GetRollDelta())
    p:SetAirResistance(gp:GetAirResistance())
    p:SetCollide(gp:GetCollide())
    p:SetBounce(gp:GetBounce())
    p:SetLighting(gp:GetLighting())
    p:SetAngleVelocity(gp:GetAngleVel())
    p:SetCollideCallback(function(part, hitpos, normal)
        hook.Run("gparticle.OnCollide", part, hitpos, normal)
    end)

    table.insert(allParticles, p)
end

hook.Add("Think", "GParticleSystem.EmitStepwise", function()
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
                    doJob(p, job)
                end
                hook.Run("gparticle.PostEmit", p, j, gp)
            end
            safeRemoveEmitter(i)
        elseif CurTime() >= job.nextEmit then
            job.current = job.current + 1
            job.nextEmit = CurTime() + job.emitRate
            local p = emitter:Add(gp:GetEffectName(), gp:GetPos())
            if p then
                local ok = hook.Run("gparticle.PreEmit", p, job.current, gp)
                if ok ~= false then
                    doJob(p, job)
                end
                hook.Run("gparticle.PostEmit", p, job.current, gp)
            end
            if job.current >= job.count then
                safeRemoveEmitter(i)
            end
        end
    end
end)

local function emit()
    if #activeEmitters >= maxEmittersCvar:GetInt() then return end
    local gp = gparticle.ReadFromNet()
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
    })
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