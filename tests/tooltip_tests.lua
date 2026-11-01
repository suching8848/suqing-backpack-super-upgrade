local X=ExSuQingBackpackSuperUpgrade
local eq,ok,case=Review.eq,Review.ok,Review.case
X.Capacity.Install();X.Tooltip.Install()
function getTextManager()return{MeasureStringX=function(self,font,text)return #text*5 end}end
function getCore()return{getScreenHeight=function()return 1080 end}end
local function panel(item)
    local p={item=item,texts={},rects=0,tooltip={}}
    function p.tooltip:getCharacter()return CurrentPlayer end
    function p.tooltip:getFont()return"Small"end
    function p.tooltip:getLineSpacing()return 15 end
    function p:getWidth()return 100 end
    function p:getHeight()return 200 end
    function p:getY()return 200 end
    function p:drawRect()self.rects=self.rects+1 end
    function p:drawRectBorder()end
    function p:drawText(text,...)self.texts[#self.texts+1]=text end
    return p
end
case("all runtime modules including Bootstrap and CreateRestore alias load",function()
    eq(type(X.CreateRestore),"function");eq(type(X.Capacity.WrapTransfer),"function");eq(type(X.Tooltip.Install),"function")
end)
case("only valid EX items receive tooltip footer without changing base render",function()
    CurrentPlayer=Character();local b=Bag(CurrentPlayer);local r=X.NewRecord(b);b.md[X.modDataKey]=r
    local p=panel(b);ISToolTipInv.render(p);eq(p.originalRenders,1);eq(#p.texts,2);eq(p.rects,1);eq(X.GetRecord(b),r)
    local ordinary=panel(Bag(CurrentPlayer));ISToolTipInv.render(ordinary);eq(ordinary.originalRenders,1);eq(#ordinary.texts,0)
end)
case("cosmetic API error preserves underlying return and EX entitlement",function()
    local p=Character();local b=Bag(p);b.md[X.modDataKey]=X.NewRecord(b)
    local bad={item=b,tooltip={getCharacter=function()error("tooltip unavailable")end}}
    local wrapped=X.Tooltip.Wrap(function()return"native render result"end)
    eq(wrapped(bad),"native render result");ok(X.IsValidRecord(X.GetRecord(b),b));eq(b.capacityWrites,0)
end)
case("context menu render check suppresses footer safely",function()
    CurrentPlayer=Character();local b=Bag(CurrentPlayer);b.md[X.modDataKey]=X.NewRecord(b);local p=panel(b)
    ISContextMenu={instance={visibleCheck=true}};ISToolTipInv.render(p);ISContextMenu=nil
    eq(p.originalRenders,1);eq(#p.texts,0)
end)
return Review.finish()
