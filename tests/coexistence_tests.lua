-- Load the REAL installed ordinary Core/Dynamic/Crafting and native Raccoon
-- override before EX modules. The engine objects themselves remain fake.
local X=ExSuQingBackpackSuperUpgrade
local C=SuQingContainerUpgrade
local eq,ok,case=Review.eq,Review.ok,Review.case
StartEvents()
ok(X.Capacity.IsReady());ok(X.Conversions.IsReady())
local function data(b)
    local d={kept=List({b})}
    function d:getAllKeepInputItems()return self.kept end
    return d
end
local function fixture()
    SandboxVars.ResidentEvilBackpackCapacity=10
    local p=Character();local b=Bag(p,"Base.ResidentEvilBackPack",49);b.wr=50;b.md.SuQingContainerUpgrade=nil
    -- The ordinary mod legitimately writes WR. Detect separately that EX does
    -- not add any physical setter calls beyond those ordinary operations.
    function b:setWeightReduction(v)self.reductionWrites=self.reductionWrites+1;self.wr=v end
    return p,b
end
case("native Raccoon original alone delegates current sandbox and traits",function()
    local p,b=fixture();eq(b.inner:getEffectiveCapacity(nil),10)
    p.trait=CharacterTrait.ORGANIZED;eq(b.inner:getEffectiveCapacity(p),13)
    eq(X.GetRecord(b),nil)
end)
case("ordinary then EX then EX restore preserves ordinary record and reduction",function()
    local p,b=fixture();ok(C.Upgrade(data(b),p,1));eq(b.inner:getEffectiveCapacity(nil),12);eq(b.wr,90)
    local ordinary=b.md.SuQingContainerUpgrade;local writes=b.reductionWrites
    ok(X.Upgrade(data(b),p));eq(X.GetRecord(b).nativeBase,10);eq(b.inner:getEffectiveCapacity(nil),20)
    eq(b.md.SuQingContainerUpgrade,ordinary);eq(b.reductionWrites,writes)
    ok(X.Restore(data(b),p));eq(b.inner:getEffectiveCapacity(nil),12);eq(b.md.SuQingContainerUpgrade,ordinary);eq(b.wr,90)
    ok(C.Restore(data(b),p));eq(b.inner:getEffectiveCapacity(nil),10);eq(b.wr,50)
end)
case("ordinary then EX then ordinary restore keeps EX entitlement",function()
    local p,b=fixture();ok(C.Upgrade(data(b),p,1));ok(X.Upgrade(data(b),p))
    local ex=X.GetRecord(b);ok(C.Restore(data(b),p));eq(b.md.SuQingContainerUpgrade,nil)
    eq(X.GetRecord(b),ex);eq(b.inner:getEffectiveCapacity(nil),20);eq(b.wr,50)
    ok(X.Restore(data(b),p));eq(b.inner:getEffectiveCapacity(nil),10)
end)
case("EX then ordinary upgrade does not use EX target as ordinary base",function()
    local p,b=fixture();ok(X.Upgrade(data(b),p));ok(C.Upgrade(data(b),p,1))
    eq(b.md.SuQingContainerUpgrade.baseCapacity,10);eq(X.GetRecord(b).nativeBase,10)
    eq(b.inner:getEffectiveCapacity(nil),20);eq(b.wr,90)
    ok(C.Restore(data(b),p));eq(b.inner:getEffectiveCapacity(nil),20);eq(b.wr,50)
end)
case("ordinary stronger capacity remains after EX floor without repeated trait multiplication",function()
    local p,b=fixture();ok(X.Upgrade(data(b),p));ok(C.Upgrade(data(b),p,1));ok(C.Upgrade(data(b),p,2));ok(C.Upgrade(data(b),p,3))
    eq(b.inner:getEffectiveCapacity(nil),30);p.trait=CharacterTrait.ORGANIZED;eq(b.inner:getEffectiveCapacity(p),39)
    ok(X.Restore(data(b),p));eq(b.inner:getEffectiveCapacity(p),39)
end)
case("ordinary and EX crafting guards chain unknown calls without swallowing results",function()
    local calls=Native.otherCrafts or 0
    eq(ISHandcraftAction.performRecipe({craftRecipe=Recipe("Foreign.Unrelated")},"unchanged"),"unchanged")
    eq(Native.otherCrafts,calls+1)
end)
case("EX disabled simulation retains ordinary Raccoon wrapper behavior",function()
    local p,b=fixture();ok(C.Upgrade(data(b),p,1));ok(X.Upgrade(data(b),p));local ex=X.GetRecord(b)
    local effective,room=Native.index.getEffectiveCapacity,Native.index.hasRoomFor
    Native.index.getEffectiveCapacity=X.Capacity.originalEffective;Native.index.hasRoomFor=X.Capacity.originalRoom
    eq(b.inner:getEffectiveCapacity(nil),12);eq(X.GetRecord(b),ex);eq(b.inner.capacity,49)
    Native.index.getEffectiveCapacity=effective;Native.index.hasRoomFor=room
    eq(b.inner:getEffectiveCapacity(nil),20)
end)
return Review.finish()
