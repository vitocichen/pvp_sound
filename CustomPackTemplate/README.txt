把本文件夹整个复制到：

  <魔兽世界>\_retail_\Interface\AddOns\

然后把文件夹改名为 PVP_Sound_Custom（必须和 PVP_Sound 并列，不要放进 PVP_Sound 里面）。

正确结构：

  Interface\AddOns\PVP_Sound\                 ← 主插件，可更新
  Interface\AddOns\PVP_Sound_Custom\          ← 本目录，更新主插件时请保留
      PVP_Sound_Custom.toc
      abc\                                    ← 你的语音包名（自定）
          IceBlock.ogg
          chaosNova.ogg
          ...

接着在游戏里输入 /ps → 语音DIY → 填写包名（如 abc）→ 点添加。
再在「语音包选择」下拉框里选中 abc。

说明：
- 点「添加」不会自动建文件夹，请先用资源管理器建好。
- 音频文件名需与内置包一致，可对照 PVP_Sound\Media\夏一可\ 里的文件名。
- 更新、覆盖 PVP_Sound 时，不要删除 PVP_Sound_Custom。
