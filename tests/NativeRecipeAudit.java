import java.lang.reflect.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Reflection into installed game classes, without starting the game. */
public class NativeRecipeAudit {
    static int assertions = 0;
    static void check(boolean condition, String label) {
        assertions++;
        if (!condition) throw new AssertionError(label);
    }
    static Field field(Class<?> cls,String name) throws Exception {
        while(cls!=null) {
            try { Field f=cls.getDeclaredField(name);f.setAccessible(true);return f; }
            catch(NoSuchFieldException ex) { cls=cls.getSuperclass(); }
        }
        throw new NoSuchFieldException(name);
    }
    public static void main(String[] args) throws Exception {
        Class<?> scriptItem=Class.forName("zombie.scripting.objects.Item");
        Object empty=scriptItem.getConstructor().newInstance();
        check(((Float)scriptItem.getMethod("getMaxItemSize").invoke(empty))==0f,
            "actual script item constructor default maxItemSize is zero");
        Class<?> parser=Class.forName("zombie.scripting.ScriptParser");
        Object root=parser.getMethod("parse",String.class).invoke(null,
            new String(Files.readAllBytes(Paths.get(args[0])),StandardCharsets.UTF_8));
        Class<?> block=root.getClass();
        Class<?> recipeClass=Class.forName("zombie.scripting.entity.components.crafting.CraftRecipe");
        Class<?> moduleClass=Class.forName("zombie.scripting.objects.ScriptModule");
        Class<?> inputClass=Class.forName("zombie.scripting.entity.components.crafting.InputScript");
        int recipeCount=0;
        for(Object mb:(List<?>)block.getField("children").get(root)) {
            check("ExSuQingBackpackSuperUpgrade".equals(block.getField("id").get(mb)),"own script module");
            for(Object rb:(List<?>)block.getField("children").get(mb)) {
                if(!"craftRecipe".equals(block.getField("type").get(rb))) continue;
                recipeCount++;
                String name=(String)block.getField("id").get(rb);
                Object recipe=recipeClass.getConstructor().newInstance();
                Object module=moduleClass.getConstructor().newInstance();
                moduleClass.getField("name").set(module,"ExSuQingBackpackSuperUpgrade");
                recipeClass.getMethod("setModule",moduleClass).invoke(recipe,module);
                field(recipeClass,"scriptObjectName").set(recipe,name);
                recipeClass.getMethod("Load",String.class,block).invoke(recipe,name,rb);
                List<?> inputs=(List<?>)recipeClass.getMethod("getInputs").invoke(recipe);
                boolean upgrade="ExSuQingSuperUpgrade".equals(name);
                check(upgrade||"ExSuQingRestore".equals(name),"only the two EX recipes");
                check(inputs.size()==(upgrade?6:1),"native input row count "+name);
                Object target=inputs.get(0);
                check((Boolean)inputClass.getMethod("isKeep").invoke(target),"target kept "+name);
                check((Boolean)inputClass.getMethod("isItemCount").invoke(target),"target counts objects "+name);
                List<?> ids=(List<?>)inputClass.getMethod("getItems").invoke(target);
                check(ids.size()==11,"native target whitelist eleven "+name);
                check(new HashSet<Object>(ids).size()==11,"native target IDs distinct "+name);
                check(ids.contains("Base.ResidentEvilBackPack"),"native target includes biological backpack");
                check(!ids.contains("Base.ResidentEvilSuspenders"),"native target excludes suspenders");
                if(upgrade) {
                    float[] amounts={1,1,40,20,20,4};
                    for(int i=0;i<inputs.size();i++)
                        check(((Float)inputClass.getMethod("getAmount").invoke(inputs.get(i)))==amounts[i],"native amount row "+i);
                    check((Boolean)inputClass.getMethod("isKeep").invoke(inputs.get(1)),"needle kept");
                    check((Boolean)inputClass.getMethod("isDestroy").invoke(inputs.get(2)),"cloth destroyed");
                    check((Boolean)inputClass.getMethod("isDestroy").invoke(inputs.get(3)),"leather destroyed");
                    check(!(Boolean)inputClass.getMethod("isItemCount").invoke(inputs.get(4)),"ordinary line counts uses");
                    check(!(Boolean)inputClass.getMethod("isItemCount").invoke(inputs.get(5)),"premium line counts uses");
                    check(((List<?>)inputClass.getMethod("getItems").invoke(inputs.get(4))).contains("Base.Thread"),"ordinary material exact ID");
                    check(((List<?>)inputClass.getMethod("getItems").invoke(inputs.get(5))).contains("Base.PremiumFishingLine"),"premium material exact ID");
                }
            }
        }
        check(recipeCount==2,"two loaded native recipes");
        System.out.println("EX_NATIVE_RECIPE assertions="+assertions+" failures=0");
    }
}
