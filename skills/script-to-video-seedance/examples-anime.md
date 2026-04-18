# Anime — Seedance 2.0 Prompt Examples

Corpus-derived reference prompts. Read before writing new prompts of this genre so the style, format, camera vocabulary, and pacing of your new prompt matches what Seedance 2.0 was trained to produce.

**Source:** YouMind community corpus — `106 total prompts classified as anime, top 12 shown.**

## 1. Sun Wukong vs. Son Goku: Cross-Style Dimensional Battle

- **Length:** 712 chars
- **Matched keywords:** `anime, 动漫, cel-shaded, 日漫`
- **Author:** {"name":"松果先森","link":"https://x.com/songguoxiansen"}
- **Source:** https://x.com/songguoxiansen/status/2021508348433301926

> A highly complex, 15-second prompt for Seedance 2.0 (or Kling) detailing a cross-dimensional battle between the classical Chinese mythological Sun Wukong (Monkey King) and the Japanese anime character Son Goku (Dragon Ball). The prompt specifies contrasting art styles (cel-shaded vs. Chinese realism…

### Prompt

```
15秒跨画风对决镜头，左侧日漫赛璐璐风格与右侧中国神话写实风格剧烈对比。0-3秒：大远景，画面正中央一道次元裂缝从天而降将画面一分为二——左侧是龙珠式的赤色岩土荒原，金发超级赛亚人状态的孙悟空单手叉腰站立，橙色战斗服紧绷肌肉线条，周身环绕金色的超级赛亚人闪电气焰；右侧是云雾缭绕的花果山，身穿锁子黄金甲、头戴凤翅紫金冠、手持如意金箍棒的古典孙悟空伫立山巅，身后祥云缭绕，两人隔裂缝对视，裂缝边缘因画风冲突而闪不稳定，伴随低沉的时空扭曲声。4-8秒：两人同时喊话——日漫悟空"你这家伙，长得跟我很像啊！"声线是少年热血动漫音，古典悟空"大胆妖猴，竟敢冒俺老孙名号！"声线是浑厚戏曲腔。两人同时冲出裂缝交错，日漫悟空一记龟派气功轰出粉蓝色能量波，古典悟空挥舞金箍棒使出一记横扫千军，能量波与金箍棒碰撞的瞬间产生画风撕裂效果——两股力量交织处画面像素化闪烁、色块崩塌重组，伴随龟派气功的"Ka-me-ha-me-HA"怒吼声与金箍棒破空的呼啸。9-12秒：定格慢放，日漫悟空开启自在极意功，全身银灰气息缭绕眼神变为冷静的银灰色，动作如闪电般闪现绕到古典悟空身后；古典悟空火眼金睛骤然亮起金红光芒，身形化作残影法天象地——身躯暴涨至百丈大小，手中金箍同步变大如擎天之柱，一棒当头砸下。13-15秒：银灰气息的极速拳影与擎天金箍棒在画面中央正面碰撞，冲击波撕裂了次元裂缝，龙珠荒原与花果山同时被能量洪流吞没，画面白光过后烟尘散去，两个背对背的身影矗立在融合后的新世界——山川与荒原交织的奇异地形，日漫悟空挠头笑说"好厉害的力量，下次再打过"，古典悟空轻捋猴须点头"待俺老孙也换个地方耍耍"，音效收束为两人同时大笑的爽朗笑声与渐弱风声。
```

---

## 2. 2D Fighting Game Sequence Prompt for Seedance 2.0

- **Length:** 2889 chars
- **Matched keywords:** `anime, cel-shaded, manga`
- **Author:** {"name":"yachimat - AI Short Anime","link":"https://x.com/yachimat_manga"}
- **Source:** https://x.com/yachimat_manga/status/2040383896244924701

> A highly structured, multi-cut prompt designed for Seedance 2.0 to generate a 2D fighting video game sequence, complete with visual configuration, character settings (using two image references), timeline, camera movements, and specific game UI elements like health bars and K.O. text.

### Prompt

```
# ═══════════════════════════════════════════════
# PROJECT: 2D Fighting Game Sequence
# SPECS: Playstation 4 / 30FPS / Budget 500M JPY
# ═══════════════════════════════════════════════

visual_config:
  style: >
    2D anime-style fighting video game screenshot,
    cel-shaded, bold outlines, gold-purple-crimson palette,
    manga-style dynamic lines, arcade game aesthetic

character_settings:
  player:
    girl: "@Image1"
    avatar: >
      psychic energy avatar, translucent golden humanoid fencer,
      Silver armor plates, glowing cyan eyes,
      appears behind user as spiritual projection
  opponent: "@Image2"

timeline:
  cut_01:
    dur: 6s
    shot: side view full shot
    prompt: >
      stylized 2D fighting video game interface,
      health bars and timer HUD overlay,
      hit counter UI incrementing,
      silver-haired girl performing rapid energy strikes,
      bright golden light effects on each motion,
      dynamic action lines radiating outward,
      special meter gauge filling up,
      neon-lit urban rooftop night stage background,
      arcade game screen composition
    cam: static side view, light screen shake on impacts

  cut_02:
    dur: 3s
    shot: extreme close-up, diagonal screen transition
    prompt: >
      sudden dramatic insert shot,
      screen splits with diagonal wipe transition,
      girl's face in extreme close-up filling frame,
      golden eyes with subtle glow, bold confident grin,
      ink-style shadows across one side of face,
      purple-gold energy aura behind head,
      abstract crimson dynamic lines in background,
      game UI text indicating special activation
    cam: instant snap zoom, tilted angle

  cut_03:
    dur: 5s
    shot: behind girl, over-the-shoulder
    prompt: >
      girl standing arms spread wide seen from behind,
      large translucent psychic avatar rising behind her,
      twice her height, golden armored plates catching light,
      expanding ring of purple-gold energy particles,
      opponent stepping back across the arena,
      background distorts with heat-shimmer effect,
      glowing particles orbit both girl and avatar,
      strong backlight creating dramatic silhouette,
      video game special move activation sequence
    cam: slow dolly in, low angle

  cut_04:
    dur: 8s
    shot: rapid multi-angle montage
    prompt: >
      avatar performs rapid successive energy projections,
      screen filled with overlapping golden light trails,
      cascading visual effects layering dynamically,
      final powerful motion sends energy wave forward,
      full-screen white flash transition,
      large stylized game UI "K.O." text appears with glass-particle burst effect,
      hit counter displays high number,
      opponent life gauge reaches zero,
      video game finishing sequence animation
    cam: rapid angle changes, final moment in slow motion
```

---

## 3. 2D Fighting Game Sequence Prompt

- **Length:** 2884 chars
- **Matched keywords:** `anime, cel-shaded, manga`
- **Author:** {"name":"ShadeLurk","link":"https://x.com/ShadeLurk"}
- **Source:** https://x.com/ShadeLurk/status/2040403855041806690

> A highly structured, multi-cut prompt for Seedance 2.0 designed to generate a sequence mimicking a 2D fighting video game, complete with HUD elements, special move activation, and a finishing sequence.

### Prompt

```
# ═══════════════════════════════════════════════
# PROJECT: 2D Fighting Game Sequence
# SPECS: Playstation 4 / 30FPS / Budget 500M JPY
# ═══════════════════════════════════════════════

visual_config:
  style: >
    2D anime-style fighting video game screenshot,
    cel-shaded, bold outlines, dark metallic stone architecture palette,
    manga-style dynamic lines, arcade game aesthetic

character_settings:
  player: "left character in @Image1"
  opponent: "right character in @Image1"

timeline:
  cut_01:
    shot: side view full shot
    prompt: >
      stylized 2D fighting video game interface,
      health bars and timer HUD overlay,
      hit counter UI incrementing,
      armored knight launches crouching uppercut lifting opponent airborne,
      blue energy sphere charges in hand then rapid golden shots pin opponent midair,
      dynamic action lines radiating outward,
      special meter gauge filling up,
      neon-lit urban rooftop night stage background,
      arcade game screen composition
    cam: static side view, light screen shake on impacts

  cut_02:
    shot: extreme close-up, diagonal screen transition
    prompt: >
      sudden dramatic insert shot,
      screen splits with diagonal wipe transition,
      knight's face in extreme close-up filling frame,
      golden eyes with subtle glow, bold confident grin,
      ink-style shadows across one side of face,
      purple-gold energy aura behind head,
      abstract crimson dynamic lines in background,
      game UI text indicating special activation
    cam: instant snap zoom, tilted angle

  cut_03:
    shot: behind knight, over-the-shoulder
    prompt: >
      knight standing arms spread wide seen from behind,
      surging golden energy aura erupting around his body,
      twice-height pillar of golden light rising behind him,
      expanding ring of purple-gold energy particles,
      opponent suspended midair stunned from combo,
      background distorts with heat-shimmer effect,
      glowing particles orbit the knight,
      strong backlight creating dramatic silhouette,
      video game special move activation sequence
    cam: slow dolly in, low angle

  cut_04:
    shot: rapid multi-angle montage
    prompt: >
      knight grabs opponent and hoists overhead into backbreaker hold,
      leaps high surrounded by concentric golden energy rings,
      plummets down with massive gold-orange-red ground impact explosion,
      cascading shockwave detonations layering gold to white repeatedly,
      full-screen white flash transition,
      large stylized game UI "K.O." text appears with glass-particle burst effect,
      hit counter displays high number,
      opponent life gauge reaches zero,
      video game finishing sequence animation
    cam: rapid angle changes, final moment in slow motion

  cut_05:
    shot: low angle tilt-up → medium shot
    prompt: >
```

---

## 4. Girl and Cat Transformation Video Prompt (Seedance 2.0)

- **Length:** 1652 chars
- **Matched keywords:** `manga, 漫画风`
- **Author:** {"name":"宇宙知识库分享","link":"https://x.com/Cosmoslucy13"}
- **Source:** https://x.com/Cosmoslucy13/status/2041908111381082463

> A highly detailed, multi-scene prompt for Seedance 2.0 to generate a video sequence featuring a girl transforming from a dark, melancholic look to an ethereal, snow-white haired goddess, incorporating elements of traditional Chinese/Japanese attire and a white cat.

### Prompt

```
少女角色：核心主体 (Subject Core) 主体类型：精致的东亚女性角色 (delicate East Asian female character) 外貌风格：唯美梦幻插画/漫画风格 (ethereal dreamy illustration/manga style) 面部特征： 皮肤：珍珠白白皙皮肤，淡粉色腮红 (pearl-like porcelain skin, soft pink blush) 眼睛：湛蓝、清澈、明亮的蓝眼睛 (bright, clear cerulean blue eyes) 表情：温柔、清澈、略带易碎感/忧郁感 (gentle, clear, fragile/melancholic expression) 嘴唇：精致、微张的唇瓣 (delicate, slightly parted lips) 配饰：精致的珍珠耳环 (delicate pearl earrings) 外貌细节 (Appearance Details) 头发： 颜色：雪白色长发 (snow-white hair) 质感：超长、蓬松、波浪形、海藻般 (ultra-long, voluminous, wavy, sea-tangled texture) 服饰： 类型：传统的和风/汉服 (traditional Japanese kimono/Hanfu style attire) 颜色：蜜桃橘色和白色相间 (peach-orange and white patterned silk) 纹理：精细的花卉图案 (intricate floral patterns) 配饰：脖子和头发上缠绕着粉色和白色小花束 (floral garlands of pink and white blossoms wrapped around the neck and hair) 关键道具 (Key Props) 伞： 类型：紫色的油纸伞/纸伞 (purple oil paper umbrella/wagasa) 细节：伞骨清晰，伞面带有微妙的丁香紫和淡紫色调 (detailed spokes visible, lilac and lavender hues on the umbrella canopy) 环境与氛围 (Environment & Atmosphere) 花瓣细节：漫天飞舞的粉色和白色樱花瓣 (drifting pink and white cherry blossom petals/cherry blossoms) 背景色调：柔和、低饱和度的马卡龙色调，包括淡紫色和淡粉色 (soft pastel macaron background, lavender, pink gradients) 光照效果：柔和、空灵、扩散的光线 (soft, ethereal, diffused light, high bloom) 整体风格：梦幻、治愈、水彩油画质感、精致的矢量插画 (dreamy, healing, watercolor and oil painting texture, detailed vector illustration, delicate linework) 氛围：宁静、神秘、治愈、温柔【伞中异瞳】(主打：空间折叠的惊悚与唯美反转) 00:00-00:03 (视觉暴击)： 灰暗的雨巷。穿着黑色卫衣的少女撑开一把普通的黑伞。突然，伞面内部亮起诡异的紫光，一只巨大、发光的白猫爪子从伞面“里面”伸了出来，一把按在少女的额头上！ 00:03-00:07 (高燃变装)： 画面瞬间爆白！黑伞碎裂成漫天飞舞的紫色油纸伞碎片，少女的黑发瞬间褪色成海藻般的雪白长发，卫衣化作蜜桃橘色的绝美汉服。 00:07-00:15 (治愈定格)： 光芒散去，少女置身于粉紫色的花海幻境。那只白猫（正常大小）轻巧地落在她的肩膀上，用毛茸茸的尾巴扫过她清澈湛蓝的眼眸，少女展露温柔的微笑。
```

---

## 5. Detailed Seedance 2.0 prompt for recreating a 90s Japanese dating sim game

- **Length:** 969 chars
- **Matched keywords:** `anime, cel-shaded`
- **Author:** {"name":"キノピオAI🍄【海賊版】","link":"https://x.com/kinopioai_ai"}
- **Source:** https://x.com/kinopioai_ai/status/2040814307487916415

> An extensive, multi-shot Seedance 2.0 prompt designed to recreate the aesthetic and atmosphere of a 90s Japanese dating simulation game (Tokimeki Memorial style). The prompt specifies the style (cel-shaded anime, pastel colors), the character (a 17-year-old girl in a sailor uniform), and a detailed …

### Prompt

```
90年代日本の恋愛シミュレーションゲーム画面、セル画調アニメ、くっきり輪郭線、桜色と暖色パステルカラー、画面下部に半透明ADVテキストウィンドウ常設、ノスタルジックで甘酸っぱい雰囲気。

ヒロイン：17歳、腰までの栗色ストレートロングヘア、前髪ぱっつん、琥珀色の大きな瞳、白セーラー服に紺スカーフとプリーツスカート、色白、頬にうっすら紅。全カットで顔と衣装の一貫性を維持。

[0-4s] 春の朝、満開の桜並木の高校校門。柔らかい朝陽、花びらがゆっくり舞う。画面奥からヒロインが歩いてくる。画面下部にテキストウィンドウ「4月——新しい季節が始まる」。淡いゴッドレイ。Camera: slow dolly in, smooth gimbal, wide to medium.

[4-8s] 午後の教室、窓から斜めに陽光。ヒロインが窓際でゆっくり振り返り、首をかしげてはにかんだ笑顔。画面下部にダイアログボックス、名前欄「藤宮 ひなた」。柔らかいディフューズドライティング。Camera: static medium shot, eye level, fixed framing.

[8-12s] 放課後の屋上、夕焼けのオレンジ空。ヒロインがフェンス越しに夕陽を見つめ、夕風が髪を揺らす。ゆっくり振り向き頬を赤らめる。ダイアログ「……来てくれたんだ」。golden hour逆光、髪にリムライト。Camera: slow dolly in, waist to bust, low angle.

[12-15s] 校庭の大きな桜の樹の下、magic hourの金色の光。ヒロインが胸の前で手を重ねうつむき、ゆっくり顔を上げて潤んだ瞳で微笑む。画面下部にゲーム選択肢ウィンドウ2つ。桜が舞う。金色レンズフレア、淡いボケ。Camera: slow dolly in to close-up, eye level, gentle smooth.

4K, Ultra HD, no deformation, natural smooth movements, stable picture, no flickering, no ghosting, sharp details. Generate video without subtitles.
```

---

## 6. Giantess Anime Climbing Scene Prompt

- **Length:** 783 chars
- **Matched keywords:** `anime, 2d animation`
- **Author:** {"name":"el.cine","link":"https://x.com/EHuanglu"}
- **Source:** https://x.com/EHuanglu/status/2041963901559173545

> A highly detailed prompt for generating a 2D anime-style video. The scene features a tiny man climbing the leg of a giantess wearing fishnet stockings, utilizing dynamic low-angle camera work to emphasize the massive scale contrast.

### Prompt

```
High-quality anime style, 2D animation. Warm, cinematic lighting with sunlight filtering through blinds. A tiny man wearing a green hoodie and blue jeans runs across a wooden floor toward a giantess. He climbs up her massive foot and leg, which are covered in black fishnet stockings, using the fishnet holes to climb. Dynamic low-angle camera following his ascent, emphasizing the colossal scale of the giantess. He climbs past her black pleated skirt and white collared shirt, scaling up her dark blue ribbed sweater. The camera pans up to reveal the giantess looking down at him. She has long brown hair, a flower hair clip, and large brown eyes. She wears a highly surprised, wide-eyed expression with a slight blush. Background is a softly blurred bedroom with a music keyboard.
```

---

## 7. Gugu Gaga Chibi Animation by the Lake

- **Length:** 545 chars
- **Matched keywords:** `anime, 2d animation`
- **Author:** {"name":"Sharon Riley","link":"https://x.com/Just_sharon7"}
- **Source:** https://x.com/Just_sharon7/status/2037728239842742454

> A detailed prompt for Seedance 2.0 to generate a 2D chibi kawaii anime style animation of the Gugu Gaga character (a girl in a penguin hoodie) by a lake, specifying character actions (head bobbing, mouth movements synced to audio), style, and vertical format.

### Prompt

```
chibi kawaii anime style: a cute black-haired penguin-hoodie girl with blue eyes and metal collar sits on a wooden bench by a lake. She bobs her head and moves her mouth cutely while making silly baby-talk sounds synced to the audio: '9 Gugu... Lol... Gugu Ga... Lol... Guguga... Lol'. Gentle body wiggles and sparkling eye animations. Bright natural daylight, serene lake background, black-white-yellow color scheme, wholesome yet chaotic meme energy, Arknights Endfield fandom aesthetic, smooth 2D animation, high detail, 9:16 vertical format.
```

---

## 8. Gojo vs Sukuna Cinematic Battle Prompt

- **Length:** 477 chars
- **Matched keywords:** `anime, 动漫`
- **Author:** {"name":"Adam也叫吉米","link":"https://x.com/Adam38363368936"}
- **Source:** https://x.com/Adam38363368936/status/2024715414174146561

> A detailed, multi-shot prompt for Seedance 2.0 to generate a cinematic battle between Gojo and Sukuna (from Jujutsu Kaisen), focusing on energy clashes, character close-ups, and a massive final explosion, emphasizing anime style and visual effects.

### Prompt

```
1. 激烈的能量对撞
让图中的红蓝能量炸裂开来，展现两人僵持不下的动感。
画面中心爆发极强的光芒，左侧银发男子释放耀眼的蓝色电光，右侧纹身男子释放暗红色的冲击波。两人保持对峙姿势，周围的地面不断崩裂，碎石受引力影响向上漂浮。镜头缓慢拉近，增强视觉压迫感。高帧率流畅动画，极致的粒子特效，硬核动漫风格。

2. 角色近景：
想要那种手指微动、咒力流转的细节感。近景特写。银发男子神情淡定，嘴角微扬。他的周围缠绕着液态般的蓝色能量，发丝随气流剧烈摆动。背景是灰暗的城市废墟。光影在角色脸上剧烈跳动，展现顶级动画质感。

3. 角色近景：
表现反派的狂气和红色咒力的压迫感。
近景特写。满脸黑色纹身的男子放声狂笑，双手合十做出复杂的印记。红色的闪电在他指尖跳跃。背景红光冲天，充满毁灭性的气息。线条硬朗，阴影对比强烈，完美复刻热血番巅峰战斗质感。

4. 毁天灭地的终结技（大场景）
展现碰撞后的剧烈爆炸。俯瞰视角。红蓝两股巨大的能量球在城市废墟中疯狂扩张、互相吞噬，最终引发巨大的球形爆炸云。白色的冲击波横扫一切建筑物。镜头剧烈震动，充满史诗般的战争史诗感。
```

---

## 9. Anime Energy Clash Fight Sequence

- **Length:** 367 chars
- **Matched keywords:** `anime, 动漫`
- **Author:** {"name":"Adam也叫吉米","link":"https://x.com/Adam38363368936"}
- **Source:** https://x.com/Adam38363368936/status/2033544163287761213

> A detailed Chinese prompt for Seedance 2.0 generating a high-energy anime fight sequence between two super-powered individuals in red and blue armor/robes. The prompt specifies character stability, dynamic action (diagonal crossing, energy clash, particle effects), a shattered dimensional ruin setti…

### Prompt

```
[主体]: 两位拥有硬核动漫线条的异能者， 穿深蓝色铠甲的战士， 穿赤红色长袍的对手， 五官清晰， 角色面部稳定不变形.
[动作]: 两位角色在空中呈斜线交叉掠过， 瞬间产生强烈的能量对冲光效， 肢体接触处绽放出极致的粒子火花， 动作连贯且带有极速感， 不僵硬.
[场景]: 破碎的次元废墟， 背景伴随大量的能量纹路和空间崩塌效果， 极高对比度的色彩， 侧逆光照耀， 展现出大片级动漫光影.
[运镜]: 采用快速甩镜(Whip Pan)在两名角色之间切换， 配合强烈的镜头震荡特效， 模拟高强度能量对撞后的物理反馈感.
[风格/画质]: 顶级动漫渲染风格， 4K超高清， 色彩饱满， 细节丰富， 锐度清晰， 电影级视觉质感， 画面丝滑无卡顿.
[约束]: 人体结构比例正常， 角色服装发型保持一致， 动作平滑不扭曲， 画面稳定无闪烁.
```

---

## 10. 2D Anime Video Prompt: White-Haired Girl Summons Water Dragon

- **Length:** 315 chars
- **Matched keywords:** `anime, 动漫`
- **Author:** {"name":"李岳","link":"https://x.com/liyue_ai"}
- **Source:** https://x.com/liyue_ai/status/2026289270370033836

> A prompt for Seedance 2.0 to generate a 2D anime video in the Guofeng (Chinese style) and Xuanji Technology art style. The scene features a cold, elegant white-haired girl in a dark blue robe, who, after a provocative line of dialogue, dramatically summons a water dragon amidst a sudden storm, empha…

### Prompt

```
动漫风格，国风2d风格，类似玄机科技的画风白发少女，扎发，冷白皮肤，兼具冷艳系长相，画面有颗粒感。

丹凤眼，闭眼姿态，表情慵懒平静，举止端庄，极致细节，极致厚涂，琉璃质感，流线笔刷。白色披着的头发，身着藏蓝色绒翎长袍，衣服的元素带有少数民族元素，整体有柔光、质感，氛围梦幻朦胧，低饱和度，富有反差故事感。头上簪着一支蓝色翡翠或者水晶垂吊簪，既显温婉又不失贵气，契合角色气质形象。

正脸示人，轻笑一声，语气轻柔又不屑说完＂哦？要抓我？＂

之后，缓缓抬眼，眼中闪炸开一丝微乎其微的光，瞬间镜头从她脸前拉远，身后瞬间乌云密布电闪雷鸣，一条水龙从天而降咆哮龙吟一声，极速飞至她头顶，霸气盘立上空，眼中红光乍现，震耳的嗡鸣声滚滚响起。
```

---

## 11. Seedance 2.0 Prompt for Anime Style White-Haired Girl

- **Length:** 312 chars
- **Matched keywords:** `anime, 动漫`
- **Author:** {"name":"AI探索者","link":"https://x.com/zhongbingzhao"}
- **Source:** https://x.com/zhongbingzhao/status/2027993656792387593

> A detailed prompt for Seedance 2.0 to generate an anime/Guofeng 2D style video featuring a white-haired girl with a cold, elegant appearance, transitioning from a calm state to a dramatic scene involving lightning and a water dragon.

### Prompt

```
动漫风格，国风2d风格，类似玄机科技的画风白发少女，扎发，冷白皮肤，兼具冷艳系长相，画面有颗粒感。 丹凤眼，闭眼姿态，表情慵懒平静，举止端庄，极致细节，极致厚涂，琉璃质感，流线笔刷。白色披着的头发，身着藏蓝色绒翎长袍，衣服的元素带有少数民族元素，整体有柔光、质感，氛围梦幻朦胧，低饱和度，富有反差故事感。头上簪着一支蓝色翡翠或者水晶垂吊簪，既显温婉又不失贵气，契合角色气质形象。 正脸示人，轻笑一声，语气轻柔又不屑说完＂哦？要抓我？＂ 之后，缓缓抬眼，眼中瞬炸开一丝微乎其微的光，瞬间镜头从她脸前拉远，身后瞬间乌云密布电闪雷鸣，一条水龙从天而降咆哮龙吟一声，极速飞至她头顶，霸气盘立上空，眼中红光乍现，震耳的嗡鸣声滚滚响起。
```

---

## 12. Prompt for Dark Fantasy Anime Battle

- **Length:** 275 chars
- **Matched keywords:** `anime, 2d animation`
- **Author:** {"name":"Kiki","link":"https://x.com/Mayz1169"}
- **Source:** https://x.com/Mayz1169/status/2041428958760284199

> A detailed video prompt for a fast-paced, 2D dark fantasy anime style magic battle, featuring a white-haired sorceress summoning a massive glowing purple magic circle and firing multiple energy bolts while shouting a Japanese phrase.

### Prompt

```
Dark fantasy anime style 2D animation. Fast-paced magic battle.

A white-haired sorceress instantly summons a massive glowing purple magic circle beneath her, arcane symbols spinning rapidly.

She raises her hand and shouts: "消え去れ！"

Multiple purple energy bolts fire forward
```

---
