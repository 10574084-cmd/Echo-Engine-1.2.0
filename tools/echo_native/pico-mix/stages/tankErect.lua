-- Echo: the stage itself (layers, filters, sniper) is native (stages/tankErect.js). This script only keeps the Tankman voice lines of the game over screen.
function onCreate()
	-- Sets and precaches the Tankman death voicelines.
	if stringStartsWith(boyfriendName, 'pico') then
		charVariant = '-pico'
		maxVoicelines = 10
	else
		charVariant = ''
		maxVoicelines = 25
	end

	for i = 1, maxVoicelines do
		precacheSound('jeffGameover'..charVariant..'/jeffGameover-'..i)
	end
end

-- Everything from here handles Tankman voiceline's when you die (skill issue dumbass). 
startedDeathSound = false
deathSoundEnded = false
function onUpdate(elapsed)
	if inGameOver == true and startedDeathSound == false then
		curAnim = (getPropertyFromGameOver('boyfriend.animation.curAnim.name') or getPropertyFromGameOver('boyfriend.atlas.anim.curSymbol.name'))
		if curAnim == 'firstDeath' then
			animEnded = (getPropertyFromGameOver('boyfriend.animation.curAnim.finished') or getPropertyFromGameOver('boyfriend.atlas.anim.finished'))
			if animEnded then
				local jeffVariant = getRandomInt(1, maxVoicelines)
				playSound('jeffGameover'..charVariant..'/jeffGameover-'..jeffVariant, 1, 'jeffVoiceline')
				startedDeathSound = true
			end
		end
	end
end

function onUpdatePost(elapsed)
	if inGameOver == true and deathSoundEnded == false then
		setSoundVolume(nil, 0.2)
	end
end

local gameOverFinished = false
function onGameOverConfirm()
	gameOverFinished = true
end

function onSoundFinished(tag)
	if tag == 'jeffVoiceline' and gameOverFinished == false then
		soundFadeIn(nil, 4, 0.2, 1)
		deathSoundEnded = true
	end
end

function getPropertyFromGameOver(property)
    if getPropertyFromClass('substates.GameOverSubstate', property) ~= nil then
        return getPropertyFromClass('substates.GameOverSubstate', property)
    else
        return getPropertyFromClass('substates.GameOverSubstate', 'instance.'..property)
    end
end