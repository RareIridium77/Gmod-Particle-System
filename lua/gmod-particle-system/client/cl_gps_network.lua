GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local gparticle = include("gparticle.lua")

local activeEmitters = {}
local sharedEmitter

local doJob = function(p, job)
    local gp = job.gp
    p:SetDieTime(gp:GetLifetime())
    p:SetStartAlpha(gp:GetStartAlpha())
    p:SetEndAlpha(gp:GetEndAlpha())
    p:SetStartSize(gp:GetStartSize())
    p:SetEndSize(gp:GetEndSize())
    p:SetColor(unpack(gp:GetColor()))
    p:SetRoll(gp:GetRoll())
    p:SetRollDelta(gp:GetRollDelta())
    p:SetVelocity(gp:GetVelocity() + VectorRand() * gp:GetSpeed())
    p:SetGravity(gp:GetGravity())
    p:SetAirResistance(gp:GetAirResistance())
    p:SetCollide(gp:GetCollide())
    p:SetBounce(gp:GetBounce())
    p:SetLighting(gp:GetLighting())
    p:SetAngleVelocity(gp:GetAngleVel())
    p:SetCollideCallback(function(part, hitpos, normal)
        hook.Run("gparticle.OnCollide", part, hitpos, normal)
    end)
end

hook.Add("Think", "GParticleSystem.EmitStepwise", function()
    for i = #activeEmitters, 1, -1 do
        local job = activeEmitters[i]

        if job.gp.emitRate <= 0 then
            for j = 1, job.count do
                local pos = job.gp:GetPos()
                local entID = job.gp:GetEntityID()
                if entID and entID > 0 then
                    local ent = Entity(entID)
                    if IsValid(ent) then
                        pos = ent:GetPos()
                    end
                end

                local p = job.emitter:Add(job.gp:GetEffectName(), pos)
                local ok = hook.Run("gparticle.PreEmit", p, j, job.gp)

                if p and ok ~= false then
                    doJob(p, job)
                end

                hook.Run("gparticle.PostEmit", p, j, job.gp)
            end

            job.emitter:Finish()
            table.remove(activeEmitters, i)
            continue
        end

        if CurTime() >= job.nextEmit then
            job.current = job.current + 1
            job.nextEmit = CurTime() + job.emitRate

            local pos = job.gp:GetPos()
            local entID = job.gp:GetEntityID()
            if entID and entID > 0 then
                local ent = Entity(entID)
                if IsValid(ent) then
                    pos = ent:GetPos()
                else
                    table.remove(activeEmitters, i)
                    continue 
                end
            end

            local p = job.emitter:Add(job.gp:GetEffectName(), pos)
            local ok = hook.Run("gparticle.PreEmit", p, job.current, job.gp)

            if p and ok ~= false then
               doJob(p, job) 
            end

            hook.Run("gparticle.PostEmit", p, job.current, job.gp)

            if job.current >= job.count then
                job.emitter:Finish()
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
    if sharedEmitter and isfunction(sharedEmitter.Finish) then
        sharedEmitter:Finish()
    end
end

net.Receive("gparticle.emit", emit)
net.Receive("gparticle.clear", clear)