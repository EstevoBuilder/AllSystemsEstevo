local PizzaGameSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

local ProfileService = require(ServerScriptService.Services.Initializer.ProfileService)
local InfoIngredientes = require(ReplicatedStorage.Modules.InfoIngredientes)
local PlaySoundFunctions = require(ReplicatedStorage.Modules.PlaySoundFunctions)
local NpcObjects = require(ReplicatedStorage.Modules.NpcObjects)

local PastaCru = ReplicatedStorage.PizzasTool.Cru
local PizzasAssadas = ReplicatedStorage.PizzasTool.Assado

local MAX_INGREDIENTES = 3
local INTERVALO_ENTRE_LANES = 2.5
local SaboresDisponiveis = {"Carnivore", "Vegetarian"}

local BillValue = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("ValueBill")

PizzaGameSystem.playerOvenData = {}

local playerPlots = {}
local friendsCache = {}
local currentFriendIndex = {}
local reloadDebounce = {}
PizzaGameSystem.FornoVerificar = {}

local VerificarEAutoVender 

-- Register and configure custom collision groups to prevent unwanted clipping
pcall(function()
	PhysicsService:RegisterCollisionGroup("NPCs")
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("NPCs", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetPlayerPlotRF = Remotes:FindFirstChild("GetPlayerPlot")

--[[
    RemoteFunction callback to fetch the player's physical plot from the workspace.
    @param playerInvoker Player: The player requesting their plot.
    @return Instance|nil: The player's plot Folder/Model, or nil if not found within the timeout.
]]
GetPlayerPlotRF.OnServerInvoke = function(playerInvoker)
	local pastaNome = playerInvoker.Name
	local pastaPlot = workspace.Terrains:FindFirstChild(pastaNome)

	if not pastaPlot then
		pastaPlot = workspace.Terrains:WaitForChild(pastaNome, 10)
	end

	return pastaPlot
end

--[[
    Helper function to locate the 'RawPizzaWithSauce' tool within the player's Character or Backpack.
    @param player Player: The target player.
    @return Tool|nil: The tool instance if found.
    @return boolean|nil: Returns true if equipped (in Character), false if in Backpack, or nil if not found.
]]
local function getPlayerDough(player)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if not character or not backpack then return nil, nil end

	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == "RawPizzaWithSauce" then return tool, true end
	end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == "RawPizzaWithSauce" then return tool, false end
	end
	return nil, nil
end

--[[
    Iterates through a model's descendants and assigns them to a specific collision group.
    @param model Instance: The target model.
    @param groupName string: The name of the target collision group.
]]
local function ApplyCollisionGroup(model, groupName)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.CollisionGroup = groupName end
	end
end

--[[
    Rotates the NPC model 180 degrees around its Y-axis via its HumanoidRootPart.
    @param npcData table: The configured NPC data table containing the Model.
]]
local function RotacionarNpc180(npcData)
	local hrp = npcData.Model:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame *= CFrame.Angles(0, math.pi, 0) end
end

--[[
    Retrieves and caches the player's friends list asynchronously with pagination handlers.
    Falsifies a single-entry list with the user's own data if no friends are found or an error occurs.
    @param player Player: The player whose friends list is being fetched.
    @return table: Array containing friend data dictionaries (Id, Username).
]]
local function GetFriendsPlayer(player)
	local userId = player.UserId
	if friendsCache[userId] then return friendsCache[userId] end

	local friends = {}
	local success, pages = pcall(Players.GetFriendsAsync, Players, userId)

	if success and pages then
		local count = 0
		repeat
			local pageSuccess, items = pcall(function() return pages:GetCurrentPage() end)
			if not pageSuccess then break end
			for _, friendData in ipairs(items) do 
				table.insert(friends, friendData) 
			end
			count = count + 1
			if not pages.IsFinished and count < 3 then
				pcall(function() pages:AdvanceToNextPageAsync() end) 
			else
				break
			end
		until pages.IsFinished
	end

	if #friends == 0 then
		table.insert(friends, {Id = player.UserId, Username = player.Name})
	end

	friendsCache[userId] = friends
	currentFriendIndex[userId] = 1
	return friends
end

--[[
    Asynchronously applies a random friend's HumanoidDescription to morph the NPC appearance.
    Cycles through the player's cached friends list iteratively.
    @param npcData table: The targeted NPC configuration data table.
    @param player Player: The player instance used to fetch the cached friends list.
]]
local function UpdateNpcAppearance(npcData, player)
	local userId = player.UserId
	local friends = friendsCache[userId]

	if not friends or #friends == 0 then
		friends = GetFriendsPlayer(player)
	end

	if not friends or #friends == 0 then return end

	local index = currentFriendIndex[userId] or 1
	local friend = friends[index]

	currentFriendIndex[userId] = (index % #friends) + 1

	task.spawn(function()
		local humanoid = npcData.Humanoid
		if humanoid then
			local success, description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, friend.Id)
			if success and description then
				local applySuccess, _ = pcall(function() 
					humanoid:ApplyDescription(description) 
				end)
				if applySuccess then
					npcData.Model.Name = friend.Username
					ApplyCollisionGroup(npcData.Model, "NPCs")
				end
			end
		end
	end)
end

--[[
    Randomly selects a flavor order for the NPC and clones the matching UI Billboard template above its head.
    @param npcData table: The targeted NPC configuration data table.
]]
local function AtribuirSaborEBillboard(npcData)
	local randomFlavor = SaboresDisponiveis[math.random(1, #SaboresDisponiveis)]
	npcData.Flavor = randomFlavor

	if npcData.Billboard then
		npcData.Billboard:Destroy()
		npcData.Billboard = nil
	end

	local templateBillboard = ReplicatedStorage:FindFirstChild("Templates"):FindFirstChild(randomFlavor)
	if templateBillboard then
		local clone = templateBillboard:Clone()
		local head = npcData.Model:FindFirstChild("Head")
		if head then
			clone.Adornee = head
			clone.Parent = npcData.Model
			clone.Enabled = false
			npcData.Billboard = clone
		end
	end
end

--[[
    Loads core animations, sets up running listeners, and registers collision groups for an NPC model.
    @param model Model: The Character model of the NPC Rig.
    @return table: Object structure storing references to animations, connections, states, and the model itself.
]]
local function ConfigurarNPC(model)
	local humanoid = model:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local idleTrack = model:FindFirstChild("Idle") and animator:LoadAnimation(model.Idle)
	local walkTrack = model:FindFirstChild("WalkAnim") and animator:LoadAnimation(model.WalkAnim)

	if idleTrack then idleTrack.Looped = true; idleTrack:Play() end
	if walkTrack then walkTrack.Looped = true end

	local runningConn = humanoid.Running:Connect(function(speed)
		if speed > 0.1 then
			if idleTrack and idleTrack.IsPlaying then idleTrack:Stop() end
			if walkTrack and not walkTrack.IsPlaying then walkTrack:Play() end
		else
			if walkTrack and walkTrack.IsPlaying then walkTrack:Stop() end
			if idleTrack and not idleTrack.IsPlaying then idleTrack:Play() end
		end
	end)

	ApplyCollisionGroup(model, "NPCs")
	return { Model = model, Humanoid = humanoid, IdleTrack = idleTrack, WalkTrack = walkTrack, Flavor = nil, Billboard = nil, ReacaoTrack = nil, RunningConnection = runningConn }
end

--[[
    Commands an NPC to walk to a designated node position and yields until the destination is reached.
    Plays a structural audio notification upon reaching the node.
    @param npcData table: The configured NPC data table.
    @param ponto BasePart: The physical position node.
]]
local function MoverNpcPara(npcData, ponto)
	if npcData and npcData.Humanoid and ponto then
		npcData.Humanoid:MoveTo(ponto.Position)
		npcData.Humanoid.MoveToFinished:Wait()

		local head = npcData.Model:FindFirstChild("Head")

		if head then
			PlaySoundFunctions.PlaySound("EffectsSounds", "Ding", head, false)
		end
	end
end

--[[
    Asynchronously interpolates a cloned item across the conveyor track via incremental CFrames.
    @param clone Instance: The cloned ingredient asset moving along the track.
    @param plotData table: The target plot configuration containing track vectors (PontoA, PontoB).
    @param duracao number: Total duration of the lifecycle in seconds.
    @param onExpire function: Callback function executed if the element reaches the end without interaction.
    @return function: A cancellation function that forces an early exit from the interpolation loop.
]]
local function startConveyorMove(clone, plotData, duracao, onExpire)
	local cancelled = false
	task.spawn(function()
		local STEP_INTERVAL = math.min(0.5, duracao / 6)
		local totalSteps = math.floor(duracao / STEP_INTERVAL)

		for step = 1, totalSteps do
			if cancelled or not clone.Parent then return end
			local t = step / totalSteps
			clone:PivotTo(CFrame.new(plotData.PontoA.Position:Lerp(plotData.PontoB.Position, t)))
			task.wait(STEP_INTERVAL)
		end

		if not cancelled and clone.Parent then onExpire() end
	end)
	return function() cancelled = true end
end

--[[
    Main algorithmic generator loop that instantiates individual material lanes based on profile configurations.
    Funnels interaction triggers through dynamic proximity prompt validations.
    @param player Player: The plot owner driving the conveyor line.
]]
local function spawnLane(player)
	local plotData = playerPlots[player.UserId]
	if not plotData then return end

	local sessionId = plotData.SessionId

	local profile = ProfileService.getProfile(player)
	local rarityLevel = profile.ConvenyorRarity or 1

	print("SpawnLane iniciado para", player.Name)

	while playerPlots[player.UserId]
		and playerPlots[player.UserId].SessionId == sessionId do

		local nomeSorteado = InfoIngredientes.GetRandomIngredientName(rarityLevel)
		if nomeSorteado == "" then task.wait(1); continue end

		local dadosIngrediente = InfoIngredientes.Ingredientes[nomeSorteado]
		local modeloOriginal = dadosIngrediente and dadosIngrediente.Ingredient
		if not modeloOriginal then task.wait(1); continue end

		local Prp = Instance.new("ProximityPrompt")
		Prp.Style = Enum.ProximityPromptStyle.Custom
		Prp.RequiresLineOfSight = false
		Prp.ActionText = ""

		local duracao = InfoIngredientes.Timer
		local coletado = false

		local clone = modeloOriginal:Clone()
		clone.Name = nomeSorteado
		clone:PivotTo(CFrame.new(plotData.PontoA.Position))
		clone.Parent = plotData.IngredientsFolder

		Prp.Parent = clone:FindFirstChild("Handle")

		CollectionService:AddTag(clone, "Ingrediente")

		local cancelMove = startConveyorMove(clone, plotData, duracao, function()
			if clone.Parent then clone:Destroy() end
		end)

		Prp.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer ~= player or coletado then 
				ReplicatedStorage.Remotes.WarnRemote:FireClient(triggerPlayer, "You’re not the boss!", Color3.new(1, 0, 0))
				return 
			end

			local profile = ProfileService.getProfile(triggerPlayer)
			if not profile or not triggerPlayer.Character then return end

			local dough, isEquipped = getPlayerDough(triggerPlayer)
			if not dough then 
				ReplicatedStorage.Remotes.WarnRemote:FireClient(player, "You don't have pizza with sauce!", Color3.new(1, 0, 0))
				return
			end

			local pizzaModel = PastaCru:FindFirstChild(nomeSorteado)
			if not pizzaModel then return end

			PlaySoundFunctions.PlaySound("EffectsSounds", "Equip", triggerPlayer.Character.HumanoidRootPart, false)

			coletado = true
			cancelMove()
			dough:Destroy()
			clone:Destroy()

			local chosen = pizzaModel:Clone()

			local temToolEquipada = triggerPlayer.Character:FindFirstChildOfClass("Tool")

			if profile.Tutorial == true then
				profile.TutorialStep = 4
				ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)
			end

			if temToolEquipada then
				chosen.Parent = triggerPlayer.Backpack
			else
				chosen.Parent = triggerPlayer.Character
			end
		end)

		task.wait(duracao)
	end
end

--[[
    Cycles the queue array for the player's customers, triggering unique animations and audio lines.
    Shifts indices and repositions other queue entities seamlessly to populate newly open nodes.
    @param player Player: The owner of the active customer queue.
    @param tipoReacao string: The thematic category key describing the feedback state ("Satisfaction" or "Rages").
]]
local function AvancarFila(player, tipoReacao)
	local plotData = playerPlots[player.UserId]
	if not plotData or plotData.FilaAndando then return end
	plotData.FilaAndando = true

	local npcAntigoFrente = plotData.CurrentNPCs[1]

	if npcAntigoFrente and tipoReacao then
		pcall(function()
			local listaSons = NpcObjects.Sounds[tipoReacao]
			if listaSons and #listaSons > 0 then
				local somSorteado = listaSons[math.random(1, #listaSons)]
				local head = npcAntigoFrente.Model:FindFirstChild("Head")
				if somSorteado and head then
					local somClone = somSorteado:Clone()
					somClone.Parent = head
					somClone:Play()
					Debris:AddItem(somClone, 4)
				end
			end

			local listaAnims = NpcObjects.Animations[tipoReacao]
			if listaAnims and #listaAnims > 0 then
				local animSorteada = listaAnims[math.random(1, #listaAnims)]
				local animator = npcAntigoFrente.Humanoid:FindFirstChildOfClass("Animator")
				if animSorteada and animator then
					local animTrack = animator:LoadAnimation(animSorteada)
					animTrack.Priority = Enum.AnimationPriority.Action
					animTrack:Play()
					npcAntigoFrente.ReacaoTrack = animTrack
				end
			end
		end)
		task.wait(1.5)
	end

	table.remove(plotData.CurrentNPCs, 1)
	table.insert(plotData.CurrentNPCs, npcAntigoFrente)

	AtribuirSaborEBillboard(plotData.CurrentNPCs[3])

	task.spawn(function()
		local npcParaC = plotData.CurrentNPCs[1]
		if npcParaC.Billboard then npcParaC.Billboard.Enabled = false end

		local npcParaB = plotData.CurrentNPCs[2]
		if npcParaB.Billboard then npcParaB.Billboard.Enabled = false end

		local npcParaA = plotData.CurrentNPCs[3]
		if npcParaA.Billboard then npcParaA.Billboard.Enabled = false end

		task.spawn(function()
			MoverNpcPara(npcParaC, plotData.NpcPoints[1])
			if npcParaC.Billboard then npcParaC.Billboard.Enabled = true end
		end)

		task.spawn(function()
			MoverNpcPara(npcParaB, plotData.NpcPoints[2])
		end)

		task.spawn(function()
			if npcParaA.ReacaoTrack then
				npcParaA.ReacaoTrack:Stop()
				npcParaA.ReacaoTrack:Destroy()
				npcParaA.ReacaoTrack = nil
			end
			MoverNpcPara(npcParaA, plotData.NpcPoints[3])
			RotacionarNpc180(npcParaA)
			UpdateNpcAppearance(npcParaA, player)
		end)

		task.wait(1.5)
		plotData.FilaAndando = false

		VerificarEAutoVender(player)
	end)
end

--[[
    Evaluates inventories automatically when 'ButtonAutoSell' is enabled.
    Matches held items against the current customer's preferred order flavor.
    @param player Player: The player whose active inventories are evaluated.
]]
VerificarEAutoVender = function(player)
	local profile = ProfileService.getProfile(player)
	if not profile or not profile.ButtonAutoSell then return end

	local plotData = playerPlots[player.UserId]
	if not plotData or plotData.FilaAndando then return end

	local npcAtual = plotData.CurrentNPCs[1]
	if not npcAtual or not npcAtual.Flavor then return end

	local todasAsFerramentas = {}
	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do 
			if item:IsA("Tool") then table.insert(todasAsFerramentas, item) end 
		end
	end
	if player:FindFirstChild("Backpack") then
		for _, item in ipairs(player.Backpack:GetChildren()) do 
			if item:IsA("Tool") then table.insert(todasAsFerramentas, item) end 
		end
	end

	for _, tool in ipairs(todasAsFerramentas) do
		if tool:GetAttribute("Assado") and not tool:GetAttribute("Burned") then
			if tool:GetAttribute("Flavor") == npcAtual.Flavor then
				local nomeSemDone = tool.Name:gsub("Done", "")
				local info = InfoIngredientes.Ingredientes[nomeSemDone]

				if info then
					if not profile.Index[tool.Name] then
						profile.Index[tool.Name] = true
					end

					ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)

					PlaySoundFunctions.PlaySound("EffectsSounds", "Ding", player.Character.Head, false)
					ProfileService.AddMoney(player, info.Value)
					tool:Destroy()

					local NumPopularity = info.Value * 2
					ProfileService.AddPopularity(player, NumPopularity)

					profile.PizzasSold += 1

					ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)

					plotData.TimerInterrompido = true
					AvancarFila(player, "Satisfaction")

					if profile.Tutorial == true then
						profile.Tutorial = false
						ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)
					end
					break
				end
			end
		end
	end
end

--[[
    Handles the async 60-second ordering timer for the frontmost customer.
    Advances the queue with negative penalties if time expires.
    @param player Player: The tracking entity linked to this timer session loop.
]]
local function GerenciarTimer(player)
	task.spawn(function()
		local plotData = playerPlots[player.UserId]
		if not plotData then return end

		local sessionId = plotData.SessionId

		while playerPlots[player.UserId]
			and playerPlots[player.UserId].SessionId == sessionId do

			plotData.TempoRestante = 60
			plotData.TimerInterrompido = false

			while plotData.TempoRestante > 0 do
				plotData.TimerText.Text = tostring(plotData.TempoRestante).."s"
				plotData.TimerText.TextColor3 = (plotData.TempoRestante <= 5) and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)

				task.wait(1)
				if not playerPlots[player.UserId] or plotData.TimerInterrompido then break end
				plotData.TempoRestante = plotData.TempoRestante - 1
			end

			if playerPlots[player.UserId] and not plotData.TimerInterrompido and plotData.TempoRestante <= 0 then
				plotData.TimerText.Text = "0s"
				plotData.TimerText.TextColor3 = Color3.fromRGB(255, 0, 0) 
				AvancarFila(player, "Rages")
				task.wait(1)
			end
		end
	end)
end

--[[
    Binds trigger listeners to custom ProximityPrompts that handle manual pizza trading interactions.
    @param player Player: The plot operator authorized to interact here.
    @param prompt ProximityPrompt: The target execution prompt.
    @return RBXScriptConnection: The established proximity trigger connection asset.
]]
local function ConfigurarPromptVenda(player, prompt)
	local conexao = prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then 
			ReplicatedStorage.Remotes.WarnRemote:FireClient(triggerPlayer, "You don't have permission to sell here.", Color3.new(1,0,0))
			return 
		end

		local plotData = playerPlots[player.UserId]
		local profile = ProfileService.getProfile(player)
		if not plotData or not profile or not player.Character or plotData.FilaAndando then return end

		local npcAtual = plotData.CurrentNPCs[1]
		if not npcAtual or not npcAtual.Flavor then return end

		local todasAsFerramentas = {}
		for _, item in ipairs(player.Character:GetChildren()) do if item:IsA("Tool") then table.insert(todasAsFerramentas, item) end end
		for _, item in ipairs(player.Backpack:GetChildren()) do if item:IsA("Tool") then table.insert(todasAsFerramentas, item) end end

		local encontrouPizzaCerta = false
		local pizzaErradaTool = nil

		for _, tool in ipairs(todasAsFerramentas) do
			if tool:GetAttribute("Assado") and not tool:GetAttribute("Burned") then
				if tool:GetAttribute("Flavor") == npcAtual.Flavor then
					local nomeSemDone = tool.Name:gsub("Done", "")
					local info = InfoIngredientes.Ingredientes[nomeSemDone]

					if info then
						if not profile.Index[tool.Name] then
							profile.Index[tool.Name] = true
						end

						ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)

						encontrouPizzaCerta = true
						PlaySoundFunctions.PlaySound("EffectsSounds", "Ding", player.Character.Head, false)
						ProfileService.AddMoney(player, info.Value)
						tool:Destroy()

						local NumPopularity = info.Value * 2
						ProfileService.AddPopularity(player, NumPopularity)

						profile.PizzasSold += 1

						ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)

						plotData.TimerInterrompido = true
						AvancarFila(player, "Satisfaction")
						break
					end
				else
					pizzaErradaTool = tool
				end
			else 
				pizzaErradaTool = tool
			end
		end

		if not encontrouPizzaCerta and pizzaErradaTool then
			pizzaErradaTool:Destroy()
			plotData.TimerInterrompido = true
			AvancarFila(player, "Rages")
		end

		if profile.Tutorial == true then
			profile.Tutorial = false
			ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)
		end
	end)

	return conexao
end

--[[
    Initializes plot settings, links tracking properties, builds customer assets, and activates lanes.
    @param player Player: The joining entity receiving plot structural instantiation.
]]
local function InicializarPlotJogador(player)
	local pastaNome = player.Name
	local pastaPlot = workspace.Terrains:WaitForChild(pastaNome, 15)
	if not pastaPlot then warn("Plot para " .. pastaNome .. " não carregou a tempo!") return end

	local plotData = {
		PontoA = nil,
		PontoB = nil,
		IngredientsFolder = nil,
		LoadRigFolder = nil,
		NpcPoints = {},
		TimerText = nil,
		CurrentNPCs = {},
		FilaAndando = false,
		TempoRestante = 0,
		TimerInterrompido = false,
		SessionId = tick(),
		SpawnThreads = {},
		Conexoes = {}
	}

	local descendentes = pastaPlot:GetDescendants()
	local npcModelsFila = {}

	for _, obj in ipairs(descendentes) do
		if obj.Name == "PontoA" then plotData.PontoA = obj
		elseif obj.Name == "PontoB" then plotData.PontoB = obj
		elseif obj.Name == "ConveyorIngredientsFolder" then plotData.IngredientsFolder = obj
		elseif obj.Name == "LoadRigFolder" then plotData.LoadRigFolder = obj
		elseif obj.Name == "TimerText" then plotData.TimerText = obj
		elseif obj.Name == "RigPointA" then plotData.NpcPoints[1] = obj
		elseif obj.Name == "RigPointB" then plotData.NpcPoints[2] = obj
		elseif obj.Name == "RigPointC" then plotData.NpcPoints[3] = obj
		elseif obj.Name == "LoadRig" or obj.Name == "LoadRig2" or obj.Name == "LoadRig3" then
			table.insert(npcModelsFila, obj)
		elseif obj:IsA("ProximityPrompt") and obj.Name == "VenderPrompt" then
			local conn = ConfigurarPromptVenda(player, obj)
			table.insert(plotData.Conexoes, conn)
		end
	end

	local connDescendant = pastaPlot.DescendantAdded:Connect(function(novoObj)
		if novoObj:IsA("ProximityPrompt") and novoObj.Name == "VenderPrompt" then
			local conn = ConfigurarPromptVenda(player, novoObj)
			if playerPlots[player.UserId] and playerPlots[player.UserId].Conexoes then
				table.insert(playerPlots[player.UserId].Conexoes, conn)
			end
		end
	end)
	table.insert(plotData.Conexoes, connDescendant)

	for _, model in ipairs(npcModelsFila) do
		local npcData = ConfigurarNPC(model)
		table.insert(plotData.CurrentNPCs, npcData)
		table.insert(plotData.Conexoes, npcData.RunningConnection)
	end

	playerPlots[player.UserId] = plotData
	GetFriendsPlayer(player)

	for i, npcData in ipairs(plotData.CurrentNPCs) do
		UpdateNpcAppearance(npcData, player)
		AtribuirSaborEBillboard(npcData)

		task.spawn(function()
			MoverNpcPara(npcData, plotData.NpcPoints[i])
			if npcData.Billboard then npcData.Billboard.Enabled = (i == 1) end
			if i == 3 then RotacionarNpc180(npcData) end
		end)
	end

	for i = 1, MAX_INGREDIENTES do
		plotData.SpawnThreads[i] = task.spawn(function()
			task.wait((i - 1) * INTERVALO_ENTRE_LANES)
			spawnLane(player)
		end)
	end

	GerenciarTimer(player)
end

--[[
    Handles player creation events, assigning specific physics behaviors and triggering plot generation.
    @param player Player: The newly joined player entity.
]]
local function OnPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		ApplyCollisionGroup(character, "Players")
	end)
	if player.Character then ApplyCollisionGroup(player.Character, "Players") end

	task.spawn(InicializarPlotJogador, player)
end

--[[
    Cleans up memory allocations, destroys tracked components, and cuts connections for a leaving player.
    @param player Player: The targeted player leaving or changing configurations.
]]
function PizzaGameSystem.DestroyPlot(player)
	local plotData = playerPlots[player.UserId]

	if plotData then
		plotData.TimerInterrompido = true

		if plotData.Conexoes then
			for _, conexao in ipairs(plotData.Conexoes) do
				if conexao and conexao.Connected then
					conexao:Disconnect()
				end
			end
			plotData.Conexoes = nil
		end

		if plotData.SpawnThreads then
			for _, thread in pairs(plotData.SpawnThreads) do
				task.cancel(thread)
			end
		end

		if plotData.IngredientsFolder then
			for _, item in ipairs(plotData.IngredientsFolder:GetChildren()) do
				item:Destroy()
			end
		end
	end

	playerPlots[player.UserId] = nil
end

--[[
    Provides a safe plot reset pipeline wrapped in debounce protections to avoid race conditions.
    @param player Player: The tracking player requesting an active plot refresh.
]]
function PizzaGameSystem.ReloadPlot(player)
	if reloadDebounce[player.UserId] then return end
	reloadDebounce[player.UserId] = true

	print("ReloadPlot seguro executado para:", player.Name)
	PizzaGameSystem.DestroyPlot(player)

	task.wait(0.5)

	InicializarPlotJogador(player)

	reloadDebounce[player.UserId] = nil
end

--[[
    RemoteEvent server listener regulating pizza state outputs post baking interaction.
    Distributes item upgrades or executes knockback explosion physics for ruined items.
    @param player Player: The player returning from the baking asset.
    @param State string: The quality modifier result ("Assou" or anything else signifying failure).
    @param listaPizzas table|string: Target data array containing structural string tags representing the pizzas.
]]
ReplicatedStorage.Remotes.OwnedPizza.OnServerEvent:Connect(function(player, State, listaPizzas)
	local profile = ProfileService.getProfile(player)
	if not profile then return end

	local ovenData = PizzaGameSystem.playerOvenData[player.UserId]
	if not ovenData then return end

	local character = player.Character
	if not character then return end

	PizzaGameSystem.FornoVerificar[player.Name] = nil

	if type(listaPizzas) == "string" then
		listaPizzas = { listaPizzas }
	elseif type(listaPizzas) ~= "table" then
		return
	end

	local jaTemToolEquipada = false
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Tool") then
			jaTemToolEquipada = true
			break
		end
	end

	for _, pizzaNome in ipairs(listaPizzas) do
		if not pizzaNome or pizzaNome == "" then continue end

		if type(ovenData) == "table" then
			local index = table.find(ovenData, pizzaNome)
			if index then
				table.remove(ovenData, index)
			end
		else
			PizzaGameSystem.playerOvenData[player.UserId] = nil
			ovenData = nil
		end

		local NameToolDone = pizzaNome .. "Done"

		if State == "Assou" then
			local pizzaAssada = PizzasAssadas:FindFirstChild(NameToolDone)
			if not pizzaAssada then continue end
			local Info = InfoIngredientes.Ingredientes[pizzaNome]
			if not Info then continue end

			local pizzaClone = pizzaAssada:Clone()
			pizzaClone:SetAttribute("Assado", true)
			pizzaClone:SetAttribute("Flavor", Info.Requirement)

			local CloneBill = BillValue:Clone()
			local ValueText = CloneBill:WaitForChild("Background"):WaitForChild("Value")

			ValueText.Text = "$"..Info.Value
			CloneBill.Parent = pizzaClone
			CloneBill.Adornee = pizzaClone

			if not jaTemToolEquipada then
				pizzaClone.Parent = character
				jaTemToolEquipada = true
			else
				pizzaClone.Parent = player.Backpack
			end

			task.spawn(function()
				task.wait(0.3)
				VerificarEAutoVender(player)
			end)
		else
			local pizzaAssada = PizzasAssadas:FindFirstChild(NameToolDone)
			if not pizzaAssada then continue end

			local pizzaClone = pizzaAssada:Clone()
			pizzaClone:SetAttribute("Burned", true)

			for _, Burned in ipairs(pizzaClone:GetDescendants()) do
				if Burned:IsA("BasePart") then
					Burned.Color = Color3.fromRGB(0, 0, 0)
				end
			end

			if not jaTemToolEquipada then
				pizzaClone.Parent = character
				jaTemToolEquipada = true
			else
				pizzaClone.Parent = player.Backpack
			end

			local hrp = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if hrp and humanoid then
				humanoid.PlatformStand = true 

				local CloneVFX = ReplicatedStorage.VFX.Explosion:Clone()
				CloneVFX.Parent = hrp
				CloneVFX:Emit(1)

				task.delay(1, function()
					CloneVFX.Enabled = false
					task.wait(1)
					CloneVFX:Destroy()
				end)

				PlaySoundFunctions.PlaySound("EffectsSounds", "Explosion", character.HumanoidRootPart, false)

				local forcaHorizontal = 50
				local forcaVertical = 30
				local direcaoKnockback = (-hrp.CFrame.LookVector * forcaHorizontal) + Vector3.new(0, forcaVertical, 0)

				local attachment = Instance.new("Attachment")
				attachment.Parent = hrp

				local linearVelocity = Instance.new("LinearVelocity")
				linearVelocity.Attachment0 = attachment
				linearVelocity.MaxForce = 500000
				linearVelocity.VectorVelocity = direcaoKnockback
				linearVelocity.Parent = hrp

				task.delay(0.2, function()
					if linearVelocity then linearVelocity:Destroy() end
					if attachment then attachment:Destroy() end
					if humanoid then humanoid.PlatformStand = false end
				end)
			end
		end
	end

	if type(PizzaGameSystem.playerOvenData[player.UserId]) == "table" 
		and #PizzaGameSystem.playerOvenData[player.UserId] == 0 then
		PizzaGameSystem.playerOvenData[player.UserId] = nil
	end

	if profile.Tutorial == true then
		profile.TutorialStep = 6
		ReplicatedStorage.Remotes.GetProfileFromLocal:FireClient(player, profile)
	end
	PlaySoundFunctions.PlaySound("EffectsSounds", "Equip", character.HumanoidRootPart, false)
end)

-- Global connections listening for joining/leaving servers
Players.PlayerAdded:Connect(OnPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do OnPlayerAdded(player) end

Players.PlayerRemoving:Connect(function(player)
	PizzaGameSystem.DestroyPlot(player)
	PizzaGameSystem.playerOvenData[player.UserId] = nil
	friendsCache[player.UserId] = nil
	currentFriendIndex[player.UserId] = nil
	reloadDebounce[player.UserId] = nil
end)

return PizzaGameSystem