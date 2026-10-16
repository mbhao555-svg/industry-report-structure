# industry-report-structure 技能自检
#
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\自检.ps1
# 退出码：0 全过；1 有失败
#
# ⚠️ 本文件必须存为 UTF-8 **带 BOM**。PowerShell 5.1 读无 BOM 的中文脚本会按 GBK 解析并语法报错。

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$pass = 0; $fail = 0; $failures = @()

function Assert {
    param([string]$Name, $Ok, [string]$Detail = '')
    if ([bool]$Ok) { $script:pass++ }
    else {
        $script:fail++
        $script:failures += "$Name$(if ($Detail) { "  →  $Detail" })"
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkRed }
    }
}
function Read-Utf8 { param([string]$Path) [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false)) }
function Has { param([string]$Text, [string]$Pattern) [bool]($Text -match $Pattern) }
function CountOf { param([string]$Text, [string]$Pattern) ([regex]::Matches($Text, $Pattern)).Count }

Write-Host ''
Write-Host '==== industry-report-structure 技能自检 ====' -ForegroundColor Cyan
Write-Host "技能目录：$Root"
Write-Host ''

# ---------- A. 自身编码 ----------
Write-Host '[A] 自身编码与文件'
$selfPath = $MyInvocation.MyCommand.Path
if (-not $selfPath) { $selfPath = Join-Path $Root '自检.ps1' }
if (Test-Path $selfPath) {
    $sb = [System.IO.File]::ReadAllBytes($selfPath)
    $hasBom = $sb.Length -ge 3 -and $sb[0] -eq 0xEF -and $sb[1] -eq 0xBB -and $sb[2] -eq 0xBF
    Assert '自检.ps1 自身为 UTF-8 带 BOM' $hasBom 'BOM 丢失：PowerShell 5.1 会按 GBK 解析中文导致语法错误'
}
$skillPath = Join-Path $Root 'SKILL.md'
Assert 'SKILL.md 存在' (Test-Path $skillPath)
if (-not (Test-Path $skillPath)) {
    Write-Host '缺少 SKILL.md，无法继续' -ForegroundColor Red
    exit 1
}
$skill = Read-Utf8 $skillPath

# ---------- B. frontmatter ----------
Write-Host '[B] frontmatter'
$fm = [regex]::Match($skill, '(?s)\A---\r?\n(.*?)\r?\n---')
Assert 'frontmatter 存在且闭合' ([bool]$fm.Success)
if ($fm.Success) {
    $body = $fm.Groups[1].Value
    $nameM = [regex]::Match($body, '(?m)^name:\s*(.+)$')
    $descM = [regex]::Match($body, '(?m)^description:\s*(.+)$')
    Assert 'frontmatter 含 name' ([bool]$nameM.Success)
    Assert 'frontmatter 含 description' ([bool]$descM.Success)
    if ($nameM.Success) {
        $nm = $nameM.Groups[1].Value.Trim()
        Assert "name 合法（当前：$nm）" ([bool]($nm -match '^[a-z0-9]+(-[a-z0-9]+)*$')) '须为小写字母数字与连字符'
        Assert 'name 为 industry-report-structure' ($nm -eq 'industry-report-structure')
    }
    if ($descM.Success) {
        $d = $descM.Groups[1].Value.Trim()
        # 只校验系统的硬上限（500）。曾自定"≤250 字符"的判据，但实测现有技能
        # 的 description 有 475／423 字符的（industry-deep-research / gzh-design），
        # 说明该阈值无依据、会误报正常技能。
        Assert "description 不超 500 字符（当前 $($d.Length)）" ($d.Length -le 500)
        Assert 'description 含触发场景描述' ((Has $d '当用户提到') -or (Has $d '当')) '触发词决定技能能否被正确加载'
    }
}

# ---------- C. 章节完整性 ----------
Write-Host '[C] 章节完整性'
$sections = @(
    '三技能分工',
    '九节信息骨架',
    '投资判断三件套',
    '投资含义矩阵',
    '可表格化的并列项清单',
    '区域集群对照表',
    '一致性核对',
    '执行流程',
    '输出格式',
    '常见结构病',
    '边界'
)
foreach ($s in $sections) {
    Assert "含章节：$s" ((CountOf $skill ([regex]::Escape($s))) -ge 1)
}

# ---------- D. 维度 A 阶段判定：判据必须【完整在内】，不得只写"见某技能" ----------
Write-Host '[D] 维度 A 阶段判定（判据完整性）'
Assert '含判断顺序五步' ((Has $skill '① 需求是否被行政命令禁止') -and (Has $skill '② 是否被更优技术整体替代') -and (Has $skill '③ 是否仍在下降') -and (Has $skill '④ 是否已止跌且剩余玩家普遍恢复盈利'))
Assert '技术终止含两步边界判定' ((Has $skill '是否【曾】被替代') -and (Has $skill '需求【现在是否仍单向转移】'))
Assert '含品类边界要点' ((Has $skill '蓝牙音箱 \+3\.9% 而智能音箱 −50\.5%') -and (Has $skill '不是"音箱"'))
Assert '含五指标投票' ((Has $skill '五指标投票') -and (Has $skill '一、增长率') -and (Has $skill '四、产品标准化'))
Assert '含三个易错点' ((Has $skill '品类定义标准') -and (Has $skill '运营服务标准') -and (Has $skill '产品标准化对服务业判别力弱'))
Assert '含非实物行业指标替换表' ((Has $skill 'SaaS／订阅') -and (Has $skill '平台／双边市场') -and (Has $skill '零售／连锁'))
Assert '含两步映射（不得编造固定阈值）' ((Has $skill '两步映射') -and (Has $skill '不得编造固定阈值'))
Assert '含渗透率七档阈值表' ((Has $skill '< 5%') -and (Has $skill '15%–20%') -and (Has $skill '> 60%'))
Assert '含渗透率两条硬规则' ((Has $skill '渗透率 < 20% → 不得判成熟期或衰退期') -and (Has $skill '渗透率 > 60% → 不得判导入期'))
Assert '含共线检查表' ((Has $skill '共线指标只算一票') -and (Has $skill '集中度高 ↔ 进入壁垒高') -and (Has $skill '不得两票'))
Assert '含冲突裁决顺序' ((Has $skill '终审') -and (Has $skill '次审') -and (Has $skill '仅参考'))
Assert '含裁决记录四项' ((Has $skill '① 冲突是什么') -and (Has $skill '④ \*\*被否决方及理由\*\*'))
Assert '含结构分化 3 倍判据' ((Has $skill '≥ 行业整体 \*\*3 倍\*\*'))
Assert '含政策性扰动三类' ((Has $skill '刺激退坡') -and (Has $skill '需求透支') -and (Has $skill '真实萎缩'))
Assert '含七个阶段标签' ((Has $skill '政策终止') -and (Has $skill '技术终止') -and (Has $skill '衰退后回稳') -and (Has $skill '导入期／成长期／成熟期／衰退期'))

# ---------- E. 维度 B 环节级利润：含可执行的取数方法 ----------
Write-Host '[E] 维度 B 环节级利润分布（含取数方法）'
Assert '含 F10 接口地址' (Has $skill 'PC_HSF10/BusinessAnalysis/PageAjax')
Assert '含 GROSS_RPOFIT_RATIO 拼写陷阱' ((Has $skill 'GROSS_RPOFIT_RATIO') -and (Has $skill 'RPOFIT'))
Assert '含跨维度相加陷阱' ((Has $skill '跨维度相加会静默放大营收') -and (Has $skill '只取单一维度'))
Assert '含 MAINOP_TYPE 说明' ((Has $skill '1=按行业 2=按产品 3=按地区'))
Assert '含四列输出要求' ((Has $skill '环节／分部') -and (Has $skill '证据来源') -and (Has $skill '样本量'))
Assert '含三条读数纪律' ((Has $skill '同一主体内跨业务比较会误导') -and (Has $skill '同一主体内跨环节对比才是最干净的证据') -and (Has $skill '单源'))
Assert '含港股不在接口范围' (Has $skill '港股与海外上市主体')

# ---------- F. 维度 C 出清机制 ----------
Write-Host '[F] 维度 C 出清机制'
Assert '含五问表' ((Has $skill '并购整合') -and (Has $skill '标准与等级') -and (Has $skill '监管门槛抬升') -and (Has $skill '渠道集中') -and (Has $skill '规模经济显著'))
Assert '含三档阈值' ((Has $skill '≥3 条') -and (Has $skill '1–2 条') -and (Has $skill '0 条'))
Assert '含规模经济 10% 判据' (Has $skill '差 ≥10%')
Assert '含碎片化陷阱与衰退期对比' ((Has $skill '碎片化陷阱：独立形态，不得与衰退期混用') -and (Has $skill '决策含义') -and (Has $skill '等不到那一天'))
# ⚠️ 原文用 Markdown 粗体（按**成长期逻辑**），断言正则须跨过 ** 标记
# ⚠️ 不写粗体标记：原文是"按**成长期逻辑**"，直接用不带 * 的短语即可稳定匹配
Assert '含两种误判与正确做法' ((Has $skill '成长期逻辑') -and (Has $skill '衰退期逻辑') -and (Has $skill '陷阱解除的前置条件'))
Assert '含逐环节判定要求' ((Has $skill '出清判定必须落到环节') -and (Has $skill '不得给行业一个统一的出清判定'))

# ---------- G. 投资含义矩阵 ----------
Write-Host '[G] 投资含义矩阵'
Assert '含 12 格矩阵' ((Has $skill '阶段 ↓ / 出清 →') -and (Has $skill '有出清机制') -and (Has $skill '出清缓慢') -and (Has $skill '碎片化陷阱'))
Assert '含最差组合标注' (Has $skill '最差组合')
Assert '含黄金窗口' (Has $skill '黄金窗口')
# ⚠️ 引号可能被编辑器统一为全角/半角，用 . 通配避免脆断言
# ⚠️ 引号字符易被编辑器统一（正文用 "" U+201C/201D，手写易成全角 ""），
#    故用 . 通配两个引号位置，避免脆断言
# ⚠️ 原文是 投"政策重开"的期权价值 —— "投"与"政策"之间还有引号，
#    故用 .{1,3} 容纳引号，不能写成 投资.政策重开（那是两个动词连写）
Assert '含三个特殊标签另判' ((Has $skill '三个特殊标签：不进矩阵') -and (Has $skill '投.{1,3}政策重开.{1,3}的期权价值') -and (Has $skill '不得按衰退期抄底逻辑操作'))
Assert '含矩阵使用纪律' ((Has $skill '阶段 ≠ 景气') -and (Has $skill '未压中') -and (Has $skill '不可达'))

# ---------- H. 可表格化清单 ----------
Write-Host '[H] 可表格化并列项'
Assert '含高发类型表' ((Has $skill '统计口径／分类代码') -and (Has $skill '产品品类') -and (Has $skill '政策沿革') -and (Has $skill '出口品类'))
Assert '含环节级利润与出清机制两行' ((Has $skill '环节级利润') -and (Has $skill '出清机制'))
Assert '含策略例外条款' ((Has $skill '策略建议必须转成投资含义') -and (Has $skill '失效条件') -and (Has $skill '是建议不是分析'))
Assert '含单元格宽度纪律' ((Has $skill '单元格宽度看单元格，不看源文件行') -and (Has $skill '>100 字符才是问题'))
Assert '含散文例外' (Has $skill '不要为用表而把推理压碎')

# ---------- I. 集群对照表 ----------
Write-Host '[I] 区域集群对照表'
Assert '含对照表标准列' ((Has $skill '集群 \| 核心区 \| 规模指标') -and (Has $skill '国家级头衔') -and (Has $skill '当前升级方向'))
Assert '含口径统一要求' ((Has $skill '规模指标必须统一口径') -and (Has $skill '等于没有这一列'))
Assert '含横向结论要求' ((Has $skill '表下写 2–3 条横向结论') -and (Has $skill '只给表不给结论'))

# ---------- J. 一致性与执行 ----------
Write-Host '[J] 一致性与执行流程'
Assert '含三种报告定位' ((Has $skill '投资分析') -and (Has $skill '产业规划／招商') -and (Has $skill '行业研究／写文章'))
Assert '含八项核对表' ((Has $skill '全文出现过"毛利率"吗') -and (Has $skill '可横向比较吗'))
Assert '含改造优先顺序六步' ((Has $skill '已有素材能判的，先判') -and (Has $skill '用 F10 接口补环节级毛利率') -and (Has $skill '若素材确实不足'))
Assert '含执行流程八步' ((Has $skill '补阶段判定') -and (Has $skill '补环节利润') -and (Has $skill '补出清机制') -and (Has $skill '填投资矩阵'))
Assert '含执行纪律：能判的必须判' ((Has $skill '能判的必须判') -and (Has $skill '本技能内置判据') -and (Has $skill '不编数字'))
# ⚠️ 必须防止"工作日志混进报告"这个曾经的错误：
# 要求技能明确区分【报告正文】与【改造记录】两个文件，且禁止把改造动作写进正文
# 用更稳的关键词：括号与全半角在编辑器中易变，不写进断言
Assert '含输出格式骨架' ((Has $skill '改造后的投资版报告') -and (Has $skill '交付物的两个文件') -and (Has $skill '判据冲突裁决记录') -and (Has $skill '区域集群对照表'))
Assert '区分报告正文与工作底稿' ((Has $skill '交付物的两个文件') -and (Has $skill '不要把工作日志混进报告') -and (Has $skill '工作底稿'))
Assert '含实测教训：工作日志是噪音' ((Has $skill '对读者是纯噪音') -and (Has $skill '不属于这四类的，一律不进报告正文'))
Assert '含正文禁词清单与交稿前扫描' ((Has $skill '正文禁词清单与交稿前扫描') -and (Has $skill '删末尾 ≠ 清干净') -and (Has $skill '八个词全部为 0') -and (Has $skill '残留 \{0\} = \{1\} 处'))
Assert '含八个禁词' ((Has $skill '改造') -and (Has $skill '本版') -and (Has $skill '原报告') -and (Has $skill '表格化') -and (Has $skill '前版'))
Assert '流程含交稿前扫描步骤' (Has $skill '交稿前扫描')
Assert '速查表含正文混入制作过程' (Has $skill '正文混入制作过程')
Assert '方法与数据来源只写四类' ((Has $skill '方法与数据来源说明') -and (Has $skill '判断结论可信度') -and (Has $skill '判断结论边界'))

# ---------- K. 边界 ----------
Write-Host '[K] 边界声明'
Assert '含不做清单' ((Has $skill '大规模检索取证') -and (Has $skill '给标的建议与估值') -and (Has $skill '编造缺失数字'))
Assert '含三项输出结尾声明' ((Has $skill '本改造基于原报告已有内容') -and (Has $skill '不构成对其准确性的背书') -and (Has $skill '结论待数据补齐后方可成立'))
Assert '指向另两个技能但不依赖' ((Has $skill 'industry-lifecycle-analyzer') -and (Has $skill 'industry-deep-research') -and (Has $skill '不再需要查另一个技能'))

# ---------- L. 排版 ----------
Write-Host '[L] 排版规范'
Assert '无 HTML 换行标签残留' (-not (Has $skill '<br\s*/?>')) '渲染器会把该标签当纯文字显示'
Assert '含表格行' ((CountOf $skill '(?m)^\|') -ge 20) '本技能以表格为主要呈现'
$fm2 = [regex]::Match($skill, '(?s)\A---\r?\n(.*?)\r?\n---')
$bodyOnly = if ($fm2.Success) { $skill.Substring($fm2.Index + $fm2.Length) } else { $skill }
Assert '正文单行不超 300 字符（frontmatter 除外）' ((CountOf $bodyOnly '(?m)^.{301,}$') -eq 0)
# ---------- 结果 ----------
Write-Host ''
Write-Host '==== 结果 ====' -ForegroundColor Cyan
Write-Host ("通过 {0} 项，失败 {1} 项" -f $pass, $fail) $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) {
    Write-Host ''
    Write-Host '失败清单：' -ForegroundColor Red
    $i = 1
    foreach ($f in $failures) { Write-Host ("  {0}. {1}" -f $i, $f) -ForegroundColor Red; $i++ }
    exit 1
}
Write-Host '技能结构、边界声明与呈现规范均通过。' -ForegroundColor Green
exit 0
