-- Independent fake engine. Runtime modules below are loaded from package unchanged.
-- These tests verify Lua branches/transactions, not real gameplay or Java hooks.
Review={cases=0,assertions=0,failures={}}
function Review.eq(actual,expected,label)
    Review.assertions=Review.assertions+1
    if actual~=expected then error((label or "equality").." expected="..tostring(expected).." actual="..tostring(actual))end
end
function Review.ok(value,label)Review.eq(not not value,true,label)end
function Review.case(name,fn)
    Review.cases=Review.cases+1
    local ok,why=pcall(fn)
    if not ok then Review.failures[#Review.failures+1]=name..": "..tostring(why)end
end
function Review.finish()
    print("EX_REVIEW cases="..Review.cases.." assertions="..Review.assertions.." failures="..#Review.failures)
    for _,failure in ipairs(Review.failures)do print("FAIL "..failure)end
    local summary="EX_REVIEW cases="..Review.cases.." assertions="..Review.assertions.." failures="..#Review.failures
    if #Review.failures>0 then error(summary.." failed: "..table.concat(Review.failures," | "))end
    return summary
end
MPClient=false;MPServer=false
function isClient()return MPClient end
function isServer()return MPServer end
function instanceof(value,kind)
    return type(value)=="table"and(value.kind==kind or(kind=="InventoryItem"and(value.kind=="InventoryContainer"or value.kind=="DrainableComboItem")))
end
function require(name)return true end
Perks={Tailoring="Tailoring"}
CharacterTrait={ORGANIZED="organized",DISORGANIZED="disorganized"}
SandboxVars={LBO={BagCapacity=49},ResidentEvilBackpackCapacity=98,ResidentEvilSuspendersCapacity=30}
Events={}
for _,name in ipairs({"OnGameStart","OnServerStarted","OnInitGlobalModData","OnLoad","OnCreatePlayer"})do
    local event={handlers={}}
    event.Add=function(fn)event.handlers[#event.handlers+1]=fn end
    Events[name]=event
end
function List(values)
    local list={values=values or{}}
    function list:size()return #self.values end
    function list:get(i)return self.values[i+1]end
    function list:add(item)self.values[#self.values+1]=item end
    function list:addAll(other)for i=0,other:size()-1 do self:add(other:get(i))end end
    function list:contains(item)for _,x in ipairs(self.values)do if x==item then return true end end;return false end
    function list:remove(item)for i,x in ipairs(self.values)do if x==item then table.remove(self.values,i);return true end end;return false end
    return list
end
ArrayList={new=function()return List()end}
local serial=100
ItemContainer={class={}}
ItemContainer.floatingPointCorrection=function(value)return value end
Native={calls=0,lastArgs=nil}
Native.index={}
function Native.index.getEffectiveCapacity(container,character)
    local cap=math.min(container.capacity,50)
    if character and character:hasTrait(CharacterTrait.ORGANIZED)then cap=math.ceil(cap*1.3)
    elseif character and character:hasTrait(CharacterTrait.DISORGANIZED)then cap=math.ceil(cap*.7)end
    return cap
end
function Native.index.hasRoomFor(container,a,b)
    Native.calls=Native.calls+1;Native.lastArgs={a,b}
    local character,item
    if b==nil then item=a else character,item=a,b end
    if container.foreignDeny then return false end
    if type(item)=="table"then
        if container.acceptItem and not container:acceptItem(item)then return false end
        if container.maxItemSize and item:getUnequippedWeight()>container.maxItemSize then return false end
    end
    local weight=type(item)=="number"and item or item:getUnequippedWeight()
    return container:getContentsWeight()+weight<=container:getEffectiveCapacity(character)
end
__classmetatables=__classmetatables or{}
__classmetatables[ItemContainer.class]={__index=Native.index}
function Container(capacity)
    local c={kind="ItemContainer",items=List(),capacity=capacity or 50,contentsWeight=0,type="inventory"}
    function c:getItems()return self.items end
    function c:contains(item)return self.items:contains(item)end
    function c:containsID(id)for _,x in ipairs(self.items.values)do if x.id==id then return true end end;return false end
    function c:getCapacity()return math.min(self.capacity,50)end
    function c:getEffectiveCapacity(character)return Native.index.getEffectiveCapacity(self,character)end
    function c:hasRoomFor(...)return Native.index.hasRoomFor(self,...)end
    function c:getContentsWeight()local n=0;for _,x in ipairs(self.items.values)do n=n+x:getUnequippedWeight()end;return n+self.contentsWeight end
    function c:getCapacityWeight()return self:getContentsWeight()end
    function c:getContainingItem()return self.owner end
    function c:getType()return self.type end
    function c:getParent()return self.parent end
    function c:getWorldItem()return self.worldItem end
    function c:hasWorldItem()return self.worldItem~=nil end
    function c:getVehiclePart()return self.vehiclePart end
    function c:isInCharacterInventory(character)return character and(self==character.inventory or(self.owner and self.owner.container==character.inventory))end
    function c:getAcceptItemFunction()return self.acceptFunction or""end
    function c:getOnlyAcceptCategory()return self.onlyCategory or""end
    function c:getMaxItemSize()return self.maxItemSize or 0 end
    function c:isItemAllowed(item)return not self.acceptItem or self:acceptItem(item)end
    function c:isInside(container)return false end
    function c:AddItem(item)
        if self.onAdd then self:onAdd(item)end
        if self.failAdd then error("injected AddItem failure")end
        if not self.items:contains(item)then self.items:add(item)end;item.container=self;return item
    end
    function c:Remove(item)
        if self.failRemove then error("injected Remove failure")end
        self.items:remove(item);if item.container==self then item.container=nil end
    end
    function c:takeItemsFrom(other)
        self.nativeCopySource=other.owner
        local contents={};for _,child in ipairs(other.items.values)do contents[#contents+1]=child end
        for _,child in ipairs(contents)do other:Remove(child);self:AddItem(child)end
    end
    return c
end
function Character(skill,trait)
    local p={kind="IsoGameCharacter",inventory=Container(),skill=skill or 10,trait=trait,worn={},wornBySlot={},primary=nil,secondary=nil}
    function p:getInventory()return self.inventory end
    function p:getPerkLevel(perk)return self.skill end
    function p:hasTrait(t)return self.trait==t end
    function p:isEquipped(item)return self.worn[item]==true end
    function p:isEquippedClothing(item)return self.worn[item]==true end
    function p:getPrimaryHandItem()return self.primary end
    function p:getSecondaryHandItem()return self.secondary end
    function p:getPlayerNum()return 0 end
    function p:getVehicle()return self.vehicle end
    function p:removeFromHands(item)if self.primary==item then self.primary=nil end;if self.secondary==item then self.secondary=nil end end
    function p:removeWornItem(item)self.worn[item]=nil;for slot,x in pairs(self.wornBySlot)do if x==item then self.wornBySlot[slot]=nil end end end
    function p:setWornItem(slot,item)local old=self.wornBySlot[slot];if old then self.worn[old]=nil end;self.worn[item]=true;self.wornBySlot[slot]=item end
    function p:getWornItem(slot)return self.wornBySlot[slot]end
    function p:setPrimaryHandItem(item)self.primary=item end
    function p:setSecondaryHandItem(item)self.secondary=item end
    function p:isTimedActionInstant()return false end
    function p:resetModel()end
    return p
end
function Material(fullType,uses)
    serial=serial+1
    local m={kind=uses~=nil and"DrainableComboItem"or"InventoryItem",fullType=fullType,uses=uses,id=serial,weight=.1,md={foreign=87},delta=fullType=="Base.PremiumFishingLine"and.25 or.05}
    function m:getFullType()return self.fullType end
    function m:getType()return string.match(self.fullType,"%.([^%.]+)$")end
    function m:getContainer()return self.container end
    function m:getWorldItem()return nil end
    function m:getModData()return self.md end
    function m:getID()return self.id end
    function m:getUnequippedWeight()return self.weight end
    function m:getActualWeight()return self.weight end
    function m:getCurrentUses()return math.floor(self.uses+0.00001)end
    function m:getCurrentUsesFloat()return self.uses*self.delta end
    function m:setCurrentUsesFloat(value)self.uses=math.floor(value/self.delta+.00001)end
    function m:getUseDelta()return self.delta end
    function m:UseAndSync()self.uses=self.uses-1 end
    function m:hasTag(tag)return false end
    function m:getCategory()return self.category or"Misc"end
    function m:getDisplayCategory()return self:getCategory()end
    function m:getScriptItem()return{getMaxItemSize=function()return 0 end}end
    function m:isHumanCorpse()return self.corpse or false end
    function m:isOnGroundOnSquare(square)return self.groundSquare==square end
    function m:isInsideBagOnSquare(square)return self.bagSquare==square end
    return m
end
function Bag(character,fullType,capacity)
    local b=Material(fullType or"LB.Bag_LegendaryBackpack_Black")
    b.kind="InventoryContainer";b.inner=Container(capacity or 49);b.inner.owner=b
    b.inner.type=b:getType();b.wr=99;b.visual={choice=0};b.capacityWrites=0;b.reductionWrites=0
    b.md={foreign={value=42},SuQingContainerUpgrade={sentinel="ordinary untouched"}}
    function b:getInventory()return self.inner end
    function b:getCapacity()return self.inner:getCapacity()end
    function b:getWeightReduction()return self.wr end
    function b:setCapacity(value)self.capacityWrites=self.capacityWrites+1;error("EX must never write physical capacity")end
    function b:setWeightReduction(value)self.reductionWrites=self.reductionWrites+1;error("EX must never write reduction")end
    function b:getFluidContainer()return self.fluid end
    function b:getEquipParent()return self.equipParent end
    function b:getMaxItemSize()return self.inner.maxItemSize or 0 end
    function b:setDrawDirty(v)self.drawDirty=v end
    function b:getModule()return string.match(self.fullType,"^([^%.]+)")end
    function b:getVisual()return self.visual end
    function b.visual:getTextureChoice()return self.choice end
    function b.visual:setTextureChoice(n)self.choice=n end
    function b.visual:getTint()return self.tint or"tint"end
    function b.visual:setTint(v)self.tint=v end
    function b.visual:getBaseTexture()return self.base or"base"end
    function b.visual:setBaseTexture(v)self.base=v end
    function b.visual:getDecal()return self.decal or"decal"end
    function b.visual:setDecal(v)self.decal=v end
    function b.visual:copyDirt(v)self.dirt=v.dirt end
    function b.visual:copyBlood(v)self.blood=v.blood end
    function b.visual:copyHoles(v)self.holes=v.holes end
    function b.visual:copyPatches(v)self.patches=v.patches end
    function b:getClothingItem()return{getTextureChoices=function()return List({"plain","bag_Patches"})end}end
    function b:canBeEquipped()return"Back"end
    function b:synchWithVisual()end
    function b:getName()return self.fullType end
    function b:getDisplayName()return self.fullType end
    function b:IsInventoryContainer()return true end
    function b:IsClothing()return false end
    function b:getItemContainer()return self.inner end
    function b:getScriptItem()return{getDisplayName=function()return self.fullType end}end
    function b:setName(v)self.displayName=v end
    function b:getColor()return self.color or"color"end
    function b:setColor(v)self.color=v end
    function b:getCondition()return self.condition or 10 end
    function b:setCondition(v)self.condition=v end
    function b:isFavorite()return self.favorite or false end
    function b:setFavorite(v)self.favorite=v end
    function b:hasModData()return true end
    function b:copyModData(source)
        local function clone(value)if type(value)~="table"then return value end;local result={};for k,v in pairs(value)do result[k]=clone(v)end;return result end
        self.md=clone(source)
        if Native.onCopy then Native.onCopy(self.inner.nativeCopySource,self)end
    end
    b.fluid={amount=0,capacity=fullType=="Base.ResidentEvilBackPack"and 3 or 1.5}
    function b.fluid:getAmount()return self.amount end
    function b.fluid:getCapacity()return self.capacity end
    function b.fluid:copyFluidsFrom(other)self.amount=other:getAmount()end
    if character then character.inventory:AddItem(b)end
    return b
end
function instanceItem(fullType)
    if string.find(fullType,"LegendaryBackpack",1,true)or fullType=="Base.ResidentEvilBackPack"then local bag=Bag(nil,fullType);bag.fluid.amount=bag.fluid.capacity;return bag end
    return Material(fullType,(fullType=="Base.Thread"and 20)or(fullType=="Base.PremiumFishingLine"and 4)or nil)
end
function Recipe(name)
    local full=string.find(name,".",1,true)and name or"ExSuQingBackpackSuperUpgrade."..name
    return{getName=function()return string.match(full,"%.([^%.]+)$")end,getScriptObjectFullType=function()return full end}
end
ISHandcraftAction={performRecipe=function(self,marker)Native.otherCrafts=(Native.otherCrafts or 0)+1;return marker or"original"end}
ISToolTipInv={render=function(self)self.originalRenders=(self.originalRenders or 0)+1 end}
function getText(key,...)return key end
function getTextOrNull(key,...)return key end
function getPlayer()return CurrentPlayer end
function getSpecificPlayer()return CurrentPlayer end
ISInventoryPage={dirtyUI=function()end}
function getPlayerInventory()return nil end
function getPlayerLoot()return nil end
ISBaseTimedAction={}
ItemTag={HEAVY_ITEM="heavy"}
function ISBaseTimedAction:derive(name)local c={Type=name};c.__index=c;setmetatable(c,{__index=self});return c end
function ISBaseTimedAction.new(self,character)return setmetatable({character=character},{__index=self})end
function ISBaseTimedAction.perform()end
function ISBaseTimedAction.stop()end
function copyClothingItem(source,target)
    local function clone(v)
        if type(v)~="table"then return v end
        local result={};for k,x in pairs(v)do result[k]=clone(x)end;return result
    end
    -- Actual Java copyModData recursively copies nested ModData. Native
    -- takeItemsFrom removes/adds the SAME child instances; fluids are copied.
    target.md=clone(source.md);target.visual.choice=source.visual.choice
    local children={};for _,child in ipairs(source.inner.items.values)do children[#children+1]=child end
    for _,child in ipairs(children)do source.inner:Remove(child);target.inner:AddItem(child)end
    if source.fluid then local amount=source.fluid:getAmount();target.fluid={getAmount=function()return amount end}end
    if Native.onCopy then Native.onCopy(source,target)end
end
function sendRemoveItemFromContainer()end
function sendAddItemToContainer()end
function sendClothing()end
function syncVisuals()end
function triggerEvent()end
function addXp()end
function getTimestampMs()return 1792585000000 end
ISTimedActionQueue={added={}}
function ISTimedActionQueue.add(action)ISTimedActionQueue.added[#ISTimedActionQueue.added+1]=action end
ISInventoryTransferAction={}
function ISInventoryTransferAction:new(character,item,source,destination,time)return{character=character,item=item,source=source,destination=destination,time=time}end
function javaTransferItems(...)Native.javaTransfers=(Native.javaTransfers or 0)+1;return"native transfer"end
function StartEvents()
    for _,fn in ipairs(Events.OnGameStart.handlers)do fn()end
end
