local X=ExSuQingBackpackSuperUpgrade
local eq,ok,case=Review.eq,Review.ok,Review.case
local originalEffective,originalRoom=Native.index.getEffectiveCapacity,Native.index.hasRoomFor
-- Core-only suite stubs the separate conversion gate. A different suite loads
-- the actual native LB action and EX conversion module end to end.
X.Conversions={IsReady=function()return true end}
ok(X.Capacity.Install(),"capacity install")
function KeepData(bag,needle)
    local data={kept=List(needle and{bag,needle}or{bag})}
    function data:getAllKeepInputItems()return self.kept end
    return data
end
local function withRecord(p,id,paid)
    local b=Bag(p,id);local r=X.NewRecord(b)
    if paid then r.paidCloth=40;r.paidLeather=20;r.paidThreadUses=20;r.paidPremiumUses=4 end
    b.md[X.modDataKey]=r;return b,r
end
case("exact 11 ID whitelist includes all ten legendary variants and excludes controls",function()
    local count=0
    for fullType in pairs(X.supported)do count=count+1;ok(X.IsSupported(Bag(nil,fullType)))end
    eq(count,11)
    for _,id in ipairs({"Base.ResidentEvilSuspenders","Base.Bag_SheetSlingBag","LB.Bag_LegendaryBackpack_NewUnknown","Base.Bag_cat_5"})do eq(X.IsSupported(Bag(nil,id)),false)end
end)
case("native business baseline is sandbox not clamped getter or ordinary record",function()
    local p=Character();local b=Bag(p,"Base.ResidentEvilBackPack",49)
    eq(X.GetNativeBase(b),98);eq(b.inner:getCapacity(),49)
    b.md.SuQingContainerUpgrade.appliedCapacity=500
    eq(X.GetNativeBase(b),98)
    local legend=Bag(p);eq(X.GetNativeBase(legend),49)
end)
case("legendary sandbox bounds match source and missing values default",function()
    local p=Character();local b=Bag(p);local old=SandboxVars.LBO.BagCapacity
    SandboxVars.LBO.BagCapacity=200;eq(X.GetNativeBase(b),100)
    SandboxVars.LBO.BagCapacity=1;eq(X.GetNativeBase(b),10)
    SandboxVars.LBO.BagCapacity=nil;eq(X.GetNativeBase(b),49)
    SandboxVars.LBO.BagCapacity="49";eq(X.GetNativeBase(b),nil)
    SandboxVars.LBO.BagCapacity=old
end)
case("raccoon invalid sandbox fails closed without mutating record",function()
    local b=Bag(Character(),"Base.ResidentEvilBackPack");local old=SandboxVars.ResidentEvilBackpackCapacity
    for _,v in ipairs({0,-1,1001,1.5,"98"})do SandboxVars.ResidentEvilBackpackCapacity=v;eq(X.GetNativeBase(b),nil);eq(X.GetRecord(b),nil)end
    SandboxVars.ResidentEvilBackpackCapacity=old
end)
case("record one fixed target and separate foreign data",function()
    local p=Character();local b=Bag(p);local foreign,ordinary=b.md.foreign,b.md.SuQingContainerUpgrade
    local allowed=X.CanUpgrade(b,p);ok(allowed);eq(X.GetRecord(b),nil)
    local changed,item=X.Upgrade(KeepData(b),p);ok(changed);eq(item,b)
    eq(X.GetRecord(b).targetCapacity,98);eq(X.CanUpgrade(b,p),false)
    eq(b.capacityWrites,0);eq(b.reductionWrites,0);eq(b.inner.capacity,49);eq(b.wr,99)
    eq(b.md.foreign,foreign);eq(b.md.SuQingContainerUpgrade,ordinary)
end)
case("corrupt fulltype multiplication and partial credit do not grant capacity",function()
    local p=Character();local b,r=withRecord(p)
    for _,change in ipairs({function(t)t.targetCapacity=196 end,function(t)t.fullType="Base.ResidentEvilBackPack"end,function(t)t.schema=2 end,function(t)t.paidPremiumUses=2 end,function(t)t.nativeBase=0 end,function(t)t.version={}end})do
        local bad=X.CopyRecord(r);change(bad);eq(X.IsValidRecord(bad,b),false);b.md[X.modDataKey]=bad
        eq(b.inner:getEffectiveCapacity(nil),49);eq(X.CanUpgrade(b,p),false)
    end
end)
case("supported EX restore only clears own key",function()
    local p=Character();local b=withRecord(p);local ordinary=b.md.SuQingContainerUpgrade;local foreign=b.md.foreign
    ok(X.Restore(KeepData(b),p));eq(X.GetRecord(b),nil);eq(b.md.SuQingContainerUpgrade,ordinary);eq(b.md.foreign,foreign)
    eq(b.inner:getEffectiveCapacity(nil),49);eq(b.capacityWrites,0);eq(b.reductionWrites,0)
end)
case("capacity target survives lower sandbox and follows higher native once",function()
    local p=Character();local b,r=withRecord(p,"Base.ResidentEvilBackPack");eq(r.targetCapacity,196)
    local old=SandboxVars.ResidentEvilBackpackCapacity
    SandboxVars.ResidentEvilBackpackCapacity=49;eq(b.inner:getEffectiveCapacity(nil),196)
    SandboxVars.ResidentEvilBackpackCapacity=300;eq(b.inner:getEffectiveCapacity(nil),300)
    eq(r.targetCapacity,196);SandboxVars.ResidentEvilBackpackCapacity=old
end)
case("traits apply once to EX floor",function()
    local p=Character();local b=withRecord(p,"Base.ResidentEvilBackPack")
    eq(b.inner:getEffectiveCapacity(p),196)
    p.trait=CharacterTrait.ORGANIZED;eq(b.inner:getEffectiveCapacity(p),255)
    p.trait=CharacterTrait.DISORGANIZED;eq(b.inner:getEffectiveCapacity(p),138)
end)
case("larger ordinary effective capacity is preserved and not multiplied again",function()
    local p=Character();local b=withRecord(p)
    local old=X.Capacity.originalEffective
    X.Capacity.originalEffective=function(c,char)return char and 130 or 100 end
    eq(b.inner:getEffectiveCapacity(p),130);eq(b.inner:getEffectiveCapacity(nil),100)
    p.trait=CharacterTrait.ORGANIZED;eq(b.inner:getEffectiveCapacity(p),130)
    X.Capacity.originalEffective=old
end)
case("nonEX unrelated containers delegate original return values and arguments",function()
    local sentinel={};local seen
    local wrapper=X.Capacity.WrapRoom(function(container,...)seen={container,...};return sentinel end)
    local p=Character();local b=Bag(p);local material=Material("Base.Stone")
    eq(wrapper(b.inner,p,material),sentinel);eq(seen[1],b.inner);eq(seen[2],p);eq(seen[3],material)
    local effective=X.Capacity.WrapEffective(function(c,char,marker)return marker end)
    eq(effective(b.inner,p,"foreign marker"),"foreign marker")
end)
case("EX item and numeric overloads permit beyond50 and refuse above98",function()
    local p=Character();local b=withRecord(p);b.inner.contentsWeight=60
    local material=Material("Base.Stone");material.weight=30
    eq(b.inner:hasRoomFor(p,material),true);eq(b.inner:hasRoomFor(p,30),true)
    eq(b.inner:hasRoomFor(p,38,0),true);eq(b.inner:hasRoomFor(p,38.01,0),false)
    material.weight=39;eq(b.inner:hasRoomFor(p,material),false)
end)
case("Lua single-item compatibility branch recognizes worn owner",function()
    local p=Character();local b=withRecord(p);b.equipParent=p;b.inner.contentsWeight=60
    local material=Material("Base.Stone");material.weight=30
    eq(b.inner:hasRoomFor(material),true)
end)
case("EX cannot accept itself or nested cyclic container",function()
    local p=Character();local b=withRecord(p)
    eq(b.inner:hasRoomFor(p,b),false)
    local m=Material("Base.Stone");b.inner.isInside=function()return true end
    eq(b.inner:hasRoomFor(p,m),false)
end)
case("EX item acceptance and per-item maximum remain enforced",function()
    local p=Character();local b=withRecord(p);local m=Material("Base.Stone");m.weight=2
    b.inner.acceptItem=function()return false end;eq(b.inner:hasRoomFor(p,m),false)
    b.inner.acceptItem=nil;b.inner.maxItemSize=1.3;eq(b.inner:hasRoomFor(p,m),false)
    m.weight=1.3;eq(b.inner:hasRoomFor(p,m),true)
    b.inner.maxItemSize=-1;m.weight=20;eq(b.inner:hasRoomFor(p,m),true)
    b.inner.maxItemSize=0;eq(b.inner:hasRoomFor(p,m),true)
end)
case("carried main inventory weight restriction is preserved for worn EX bag",function()
    local p=Character();local b=withRecord(p);b.equipParent=p
    local m=Material("Base.Stone");m.weight=20;p.inventory.contentsWeight=40
    eq(b.inner:hasRoomFor(p,m),false)
    p.inventory.contentsWeight=0;eq(b.inner:hasRoomFor(p,m),true)
end)
case("world floor50 total restriction and explicit floor delta are preserved",function()
    local p=Character();local b=withRecord(p);p.inventory:Remove(b)
    local sq={getTotalWeightOfItemsOnFloor=function()return 49 end}
    b.inner.worldItem={getSquare=function()return sq end}
    eq(b.inner:hasRoomFor(p,2),false);eq(b.inner:hasRoomFor(p,2,0),true)
    local m=Material("Base.Stone");m.weight=2;m.groundSquare=sq
    eq(b.inner:hasRoomFor(p,m),true)
    sq.getTotalWeightOfItemsOnFloor=function()return 53 end
    eq(b.inner:hasRoomFor(p,2,-5),true)
end)
case("vehicle parent capacity remains enforced",function()
    local p=Character();local b=withRecord(p);local outer=Container(20);outer.vehiclePart={};outer.contentsWeight=18;outer:AddItem(b)
    eq(b.inner:hasRoomFor(p,3),false);eq(b.inner:hasRoomFor(p,1),true)
end)
case("invalid input overload or unknown API failure denies insertion",function()
    local p=Character();local b=withRecord(p)
    eq(b.inner:hasRoomFor(p,-1),false);eq(b.inner:hasRoomFor(p,0/0),false)
    eq(b.inner:hasRoomFor(p,{}),false);eq(b.inner:hasRoomFor(p,1,0/0),false)
    eq(b.inner:hasRoomFor(p,1,math.huge),false);eq(b.inner:hasRoomFor(p,1,-math.huge),false)
    eq(b.inner:hasRoomFor({},1),false)
    b.inner.isItemAllowed=function()error("foreign API failure")end
    eq(b.inner:hasRoomFor(p,Material("Base.Stone")),false)
end)
case("preconditions reject skill worn held contents fluid and wrong inventory",function()
    local p=Character(4);local b=Bag(p)
    eq(X.CanUpgrade(b,p),false);p.skill=5;ok(X.CanUpgrade(b,p))
    p.worn[b]=true;eq(X.CanUpgrade(b,p),false);p.worn[b]=nil
    p.primary=b;eq(X.CanUpgrade(b,p),false);p.primary=nil
    local m=Material("Base.Stone");b.inner:AddItem(m);eq(X.CanUpgrade(b,p),false);b.inner:Remove(m)
    b.fluid={getAmount=function()return.0001 end};eq(X.CanUpgrade(b,p),false);b.fluid=nil
    p.inventory:Remove(b);eq(X.CanUpgrade(b,p),false)
end)
case("probes leave own and foreign data unchanged and never use setters",function()
    local p=Character();local b=Bag(p);local ordinary=b.md.SuQingContainerUpgrade;local foreign=b.md.foreign
    local ready,reason,snapshot,target=X.ProbeChange(b,p,"upgrade");ok(ready,reason);eq(target,98);eq(X.GetRecord(b),nil)
    eq(b.md.SuQingContainerUpgrade,ordinary);eq(b.md.foreign,foreign);eq(b.capacityWrites,0);eq(b.reductionWrites,0)
end)
case("recipe identity requires full own module",function()
    eq(X.GetRecipeMode(Recipe("ExSuQingSuperUpgrade")),"upgrade");eq(X.GetRecipeMode(Recipe("ExSuQingRestore")),"restore")
    eq(X.GetRecipeMode(Recipe("Foreign.ExSuQingSuperUpgrade")),nil);eq(X.GetRecipeMode(nil),nil)
end)
case("MP delegates capacity and disallows paid action",function()
    local p=Character();local b=withRecord(p)
    MPClient=true;eq(b.inner:getEffectiveCapacity(nil),49);eq(X.Capacity.IsReady(),false);eq(X.CanUpgrade(Bag(p),p),false);MPClient=false
end)
case("foreign later wrapper makes new payment fail closed without restacking",function()
    local old=Native.index.getEffectiveCapacity
    Native.index.getEffectiveCapacity=function(...)return old(...)end
    eq(X.Capacity.IsReady(),false);eq(X.Capacity.Install(),false)
    local p=Character();eq(X.CanUpgrade(Bag(p),p),false)
    Native.index.getEffectiveCapacity=old;ok(X.Capacity.IsReady())
end)
case("missing transfer helper blocks payment then late helper installs without stacking",function()
    local transfer=javaTransferItems;local installed=X.Capacity.installedTransfer
    javaTransferItems=nil;X.Capacity.installedTransfer=nil
    eq(X.Capacity.IsReady(),false);eq(X.Capacity.Install(),false)
    local p=Character();eq(X.CanUpgrade(Bag(p),p),false)
    javaTransferItems=function()return"late native helper"end
    ok(X.Capacity.Install());ok(X.Capacity.IsReady())
    eq(Native.index.getEffectiveCapacity,X.Capacity.installedEffective)
    eq(Native.index.hasRoomFor,X.Capacity.installedRoom)
    javaTransferItems=transfer;X.Capacity.installedTransfer=installed
    ok(X.Capacity.IsReady())
end)
case("later transfer helper override blocks payment and does not stack",function()
    local transfer=javaTransferItems
    javaTransferItems=function(...)return transfer(...)end
    eq(X.Capacity.IsReady(),false);eq(X.Capacity.Install(),false)
    local p=Character();eq(X.CanUpgrade(Bag(p),p),false)
    javaTransferItems=transfer;ok(X.Capacity.IsReady())
end)
case("later room override blocks payment and does not stack",function()
    local room=Native.index.hasRoomFor
    Native.index.hasRoomFor=function(...)return room(...)end
    eq(X.Capacity.IsReady(),false);eq(X.Capacity.Install(),false)
    Native.index.hasRoomFor=room;ok(X.Capacity.IsReady())
end)
case("disable simulation removes overlay leaves saved entitlement inert",function()
    local p=Character();local b,r=withRecord(p)
    eq(b.inner:getEffectiveCapacity(nil),98)
    Native.index.getEffectiveCapacity=originalEffective;Native.index.hasRoomFor=originalRoom
    eq(b.inner:getEffectiveCapacity(nil),49);eq(X.GetRecord(b),r);eq(b.inner.capacity,49)
    Native.index.getEffectiveCapacity=X.Capacity.installedEffective;Native.index.hasRoomFor=X.Capacity.installedRoom
    eq(b.inner:getEffectiveCapacity(nil),98);eq(X.GetRecord(b),r)
end)
return Review.finish()
