GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local gparticle = include("gparticle.lua")

local activeEmitters = {}
local allParticles = {}

local doJob = function(p, job)
    local gp = job.gp
    local pos = gp:GetPos()

    local entID = gp:GetEntityID()
    if entID and entID > 0 then
        local ent = Entity(entID)
        if not IsValid(ent) then
            gp:SetEntityID(nil)
            job.emitter:Finish()
            table.remove(activeEmitters, i)
        else
            local maxs = ent:OBBMaxs().z * 0.5
            pos = ent:GetPos() + ent:GetUp() * maxs
            p:SetVelocityScale(true)
        end
    end

    p:SetPos(pos)

    local wind = gp:GetWind() or vector_origin
    if wind ~= vector_origin then
        local windDragForce    = wind * 0.1
        local dragAdd = windDragForce * 0.015

        p:SetNextThink(CurTime())

        debugoverlay.Line(pos, pos + wind, 1, Color(0, 255, 255), true)
        debugoverlay.Text(pos + Vector(0, 0, 10), "Wind", 1, true)

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

        if gp:GetParticleID() then
            debugoverlay.Text(
                gp:GetPos(),
                gp:GetParticleID(),
                1,
                true
            )
        end

        if gp.emitRate <= 0 then
            local emitter = job.emitter
            
            for j = 1, job.count do
                local pos = gp:GetPos()

                if not emitter then continue end

                local p = emitter:Add(gp:GetEffectName(), pos)
                local ok = hook.Run("gparticle.PreEmit", p, j, gp)

                if not p then
                    emitter:Finish()
                    table.remove(activeEmitters, i)
                    continue
                end

                if p and ok ~= false then
                    doJob(p, job)
                end

                hook.Run("gparticle.PostEmit", p, j, gp)
            end

            emitter:Finish()
            table.remove(activeEmitters, i)
            continue
        end

        if CurTime() >= job.nextEmit then
            job.current = job.current + 1
            job.nextEmit = CurTime() + job.emitRate

            local pos = gp:GetPos()
            local emitter = job.emitter

            if not emitter then continue end

            local p = emitter:Add(gp:GetEffectName(), pos)
            local ok = hook.Run("gparticle.PreEmit", p, job.current, gp)

            if p and ok ~= false then
               doJob(p, job) 
            end

            hook.Run("gparticle.PostEmit", p, job.current, gp)

            if job.current >= job.count then
                emitter:Finish()
                table.remove(activeEmitters, i)
            end
        end
    end
end)

local function emit()
    local gp = gparticle.ReadFromNet()
    local count = gp:GetCount()
    local rate = gp:GetEmitRate() or 0

    table.insert(activeEmitters, {
        gp = gp,
        count = count,
        current = 0,
        emitRate = rate,
        nextEmit = CurTime(),
        emitter = ParticleEmitter(gp:GetPos(), gp:GetUse3D())
    })
end

local function clear()
    for i = #activeEmitters, 1, -1 do
        local job = activeEmitters[i]
        if job and job.emitter and isfunction(job.emitter.Finish) then
            job.emitter:Finish()
        end
        table.remove(activeEmitters, i)
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