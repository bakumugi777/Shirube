# 標（Shirube）

[English](README.en.md)

画面左端から差す淡い光の中に、現在のデスクトップ状態を浮かべる
Niri / Wayland向けQuickShellインターフェースです。

現在はWindow Overviewを対象外とし、システム状態、ワークスペース、時計、光場表現と
外部IPCを中心とした構成です。Kanameは独立アプリのまま、必要な場合だけQuickShell
プロセスを共有できます。

> [!NOTE]
> Shirubeは作者が自分の環境で使うために作った個人プロジェクトで、AIの支援を受けて開発しています。
> 現時点で動作確認できているのは作者の環境のみです。ほかの構成での動作は保証されないため、
> 導入時はこの点を了承してください。あくまで作者自身の用途を優先するため、機能要望への対応や、
> 継続的な保守・更新は約束しません。

## 主な機能

- 90pxの通常光と、変形用の入力透過な描画領域、64pxの左固定exclusive zone
- 背景から分離し、既存ウィンドウ上へ右方向に減衰する多層光場
- 漢数字時計
- 平滑化したCPUリングとMemoryリング
- Audioの通常／ミュート表示
- Network接続表示
- Battery搭載端末でのみ表示される残量リングと充電詳細
- Niri / Hyprlandの漢数字ワークスペース表示

## インストール（NixOS・推奨）

ShirubeはNix Flakeでの導入を推奨します。GitHubから直接動作確認できます。

```sh
nix run github:bakumugi777/Shirube
```

ユーザープロファイルへ導入する場合：

```sh
nix profile install github:bakumugi777/Shirube#shirube
shirube
```

NixOS構成へ組み込む場合は、このFlakeをinputへ追加します。

```nix
{
  inputs.shirube.url = "github:bakumugi777/Shirube";

  outputs = { nixpkgs, shirube, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        shirube.nixosModules.default
        {
          programs.shirube.enable = true;
          programs.shirube.autostart = true;
        }
      ];
    };
  };
}
```

Home Managerを使用する場合：

```nix
{
  imports = [ inputs.shirube.homeManagerModules.default ];
  programs.shirube.enable = true;
  programs.shirube.autostart = true;
}
```

両モジュールとも、`graphical-session.target`に連動するsystemdユーザーサービスを作成します。
設定は`~/.config/shirube/config.json`、Matugen出力は
`~/.config/shirube/matugen-colors.json`へ保存され、パッケージ更新後も維持されます。

## その他のLinux

QuickShell 0.3.xとCコンパイラを導入後、次を実行します。

```sh
sh install.sh
systemctl --user enable --now shirube.service
```

アンインストールではユーザー設定を保持します。設定も削除する場合だけ`--purge`を付けます。

```sh
sh uninstall.sh
sh uninstall.sh --purge
```

## 開発時の起動

開発時も依存関係を含むFlake経由で起動します。

```sh
nix run .
```

公開前とCIで使用する一括検査：

```sh
nix flake check
```

パッケージビルド、シェルスクリプトのShellCheck、JSON構文検査が実行されます。

状態取得には `/proc`、`/sys/class/power_supply`、`niri msg`、`wpctl`、`nmcli` を使用します。コマンドが存在しない、
または対象サービスが利用できない場合もシェル自体は起動し、該当項目は未接続状態として表示します。

### 外部操作（IPC）

起動中のShirubeは、NiriやHyprlandのキーバインドなどから操作できます。

```bash
shirube toggle audio
shirube open cpu
shirube close
```

対象モジュールは`cpu`、`memory`、`audio`、`network`、`battery`、`calendar`です。
`mem`、`volume`、`net`、`bat`、`clock`などの短縮名も利用できます。`close`は展開内容だけを
収納し、Shirube本体は終了しません。本体を終了する場合は`shirube quit`を使用します。

### Kanameとの任意のプロセス共有

ShirubeとKanameは独立したアプリケーションであり、通常のShirubeパッケージにKanameは
含まれません。両方を個別にインストールした利用者だけ、各QMLコンポーネントを一つの
`ShellRoot`へ配置してQuickShellプロセスを共有できます。

構成例は`examples/shared-shell/`にあります。共有時は同じ設定ディレクトリを両CLIへ指定します。

```sh
SHIRUBE_QML_DIR=/path/to/shared shirube toggle audio
KANAME_QML_DIR=/path/to/shared kaname --applications
```

共有構成を使う場合、Shirube単独サービスと`kaname-shell`は同時に起動しません。

Home Managerでは、ShirubeとKanameをそれぞれ独立したFlake inputとして追加したうえで
次のように設定できます。

```nix
{
  imports = [ inputs.shirube.homeManagerModules.default ];

  programs.shirube = {
    enable = true;
    autostart = true;
    sharedShell = {
      enable = true;
      kanamePackage =
        inputs.kaname.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
}
```

NixOSモジュールでも同じオプションを使用します。

```nix
{
  programs.shirube = {
    enable = true;
    autostart = true;
    sharedShell = {
      enable = true;
      kanamePackage =
        inputs.kaname.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
}
```

有効にすると共有`ShellRoot`、両QMLモジュール、CLI用の`SHIRUBE_QML_DIR`と
`KANAME_QML_DIR`、systemdユーザーサービスが生成されます。Kanameの単独自動起動は
無効にしてください。`sharedShell.enable = false`の既定状態ではKanameを評価・導入しません。

Niriで音量詳細を開閉する例：

```kdl
Mod+V { spawn "shirube" "toggle" "audio"; }
```

## 依存関係

- 必須：QuickShell 0.3.x、NiriまたはHyprland
- 音声表示・反応：PipeWire、WirePlumber（`pw-record`、`wpctl`）
- ネットワーク表示：NetworkManager（`nmcli`）
- 初期Action：Wofi、wlogout
- 推奨フォント：Makinas
- 自動配色：Matugen 4.x

FlakeパッケージにはQuickShell、PipeWire／WirePlumber、NetworkManagerと解析ヘルパーを含めます。
Wofi、wlogout、Makinas、Matugenは利用者が選べる任意依存です。

表示フォントはMakinasを推奨します。未導入の場合はNoto Sans CJK JP、さらにシステムの
sans-serifへ順にフォールバックするため、Makinasは必須依存ではありません。

## 設定

外観と更新間隔は `config.json` から変更できます。ファイルは監視されており、保存すると
再読み込みされます。項目が欠けている場合やJSONが不正な場合は内蔵の既定値を使用します。
実際に読み込まれる場所は`~/.config/shirube/config.json`です。全項目を含むコピー元は
[`config.json`](config.json)にあります。

### フォント

| キー | 既定値 | 内容 |
| --- | ---: | --- |
| `font.family` | `Makinas` | 優先フォント |
| `font.fallbacks` | `Noto Sans CJK JP`, `sans-serif` | 代替フォント |
| `font.moduleSize` | `14` | モジュール文字サイズ |
| `font.workspaceSize` | `14` | ワークスペース文字サイズ |
| `font.clockSize` | `16` | 時計文字サイズ |
| `font.weight` | `500` | 通常文字の太さ |
| `font.letterSpacing` | `1.5` | 文字間隔 |

### 基本レイアウト

| キー | 既定値 | 内容 |
| --- | ---: | --- |
| `layout.exclusiveZoneWidth` | `64` | ウィンドウ配置から確保する幅 |
| `layout.compactSurfaceWidth` | `90` | 通常UIの基準幅 |
| `layout.lightWidth` | `90` | 通常光の基準幅 |
| `layout.expandedSurfaceWidth` | `380` | 変形を描画できる最大幅 |
| `layout.moduleAxis` | `26` | モジュール中心のX座標 |

`exclusiveZoneWidth`はタイルウィンドウを実際に縮めます。一方、描画面の透明部分は
マウス入力を奪いません。

### 外観設定一覧

| キー | 既定値 | 内容 |
| --- | ---: | --- |
| `appearance.idleOpacity` / `subduedOpacity` / `hoverOpacity` | `1.0` / `0.50` / `1.0` | 状態別不透明度 |
| `appearance.hologramPanelOpacity` | `0.12` | 詳細背後の面の濃さ |
| `appearance.glowIntensity` / `textGlowIntensity` | `1.4` / `1.0` | 全体・文字の発光量 |
| `appearance.paletteTransitionMs` | `650` | 配色補間時間 |
| `appearance.ambientAnimationEnabled` | `true` | 常時演出の一括切り替え |
| `appearance.floatingEnabled` / `floatingAmplitude` / `floatingPeriodMs` | `true` / `1.1` / `7200` | 浮遊の有効化・量・周期 |
| `appearance.lightWaveEnabled` / `lightWaveAmplitude` | `true` / `8.0` | 波の有効化・振幅 |
| `appearance.lightWavePeriodMs` / `lightWaveFps` | `3000` / `10` | 波の周期・更新頻度 |
| `appearance.lightFieldStripHeight` | `5` | 描画刻み。小さいほど滑らかで高負荷 |
| `appearance.audioReactionEnabled` / `audioReactionStrength` | `true` / `0.90` | 音声反応の有効化・変形量 |
| `appearance.audioReactionAttackMs` / `audioReactionReleaseMs` | `90` / `380` | 音声反応の立上り・戻り時間 |
| `appearance.audioReactionBrightness` | `1.35` | 音声反応時の明度 |
| `appearance.audioReactionSmoothingMs` | `360` | 旧設定との互換値 |

### アニメーションと更新周期

| キー | 既定値 | 内容 |
| --- | ---: | --- |
| `animation.enabled` | `true` | アニメーションと音声解析の一括切り替え |
| `animation.interactionMs` | `280` | 展開・収納・切り替え時間 |
| `animation.startupLightMs` | `720` | 起動時の光の展開時間 |
| `animation.startupUiDelayMs` / `startupUiMs` | `260` / `520` | UI出現の待ち時間・所要時間 |
| `updates.systemMs` | `2000` | CPU・メモリ更新周期 |
| `updates.desktopMs` / `audioMs` | `3000` / `3000` | 互換周期・音量更新周期 |
| `updates.networkMs` / `batteryMs` | `6000` / `15000` | 通信・電池更新周期 |
| `updates.workspaceFallbackMs` | `2000` | ワークスペース補助更新周期 |

時間の単位はmsです。ワークスペース更新はコンポジタのイベントを優先します。

`colors`では文字、モジュール、リング、発光、光場の各段階を個別指定できます。
手動指定に利用できるキーは、`config.json`の`colors`セクションがそのまま既定パレット兼
サンプルになっています。保存を検知するとQMLを再起動せずに配色が反映されます。
通常文字の輪郭外へ広がる発光量は`appearance.textGlowIntensity`で調整できます。

通常は現在の青色パレットをそのまま使用します。ルートに有効な`matugen-colors.json`が存在する
場合だけ、その`accent`、`text`、`surface`から発光用の階調を自動生成します。`secondary`と
`tertiary`も存在する場合は、壁紙の主色由来の`accent`から色相が最も離れた候補を発光色に選びます。
旧形式の3色ファイルも引き続き利用できます。

候補の比較にはHSL色相環上の最短距離を使います。色相を`0.0`〜`1.0`の円として扱い、
`min(abs(a - b), 1 - abs(a - b))`で`accent`と各候補の距離を求めます。これは壁紙の各ピクセルを
解析する処理ではなく、Matugenの`primary`を壁紙の代表色とみなす低負荷な近似です。候補選択時に
明度差・彩度差は評価しません。
暗すぎるアクセントは最低明度・彩度を補正するため、壁紙へ溶け込みすぎて動きが見えなくなるのを
防ぎます。`colors.overrides`へ個別キーを書くと、既定色・Matugen色のどちらでもその色を最優先できます。
ファイルが存在しない、JSONが壊れている、3色のいずれかが欠けている、色が正しい16進表記でない
場合は自動的に既定パレットへ戻ります。
有効化・更新・フォールバック時はいずれも全配色を同時に補間します。切替時間は
`appearance.paletteTransitionMs`で指定でき、既定値は`650`msです。`animation.enabled`が
`false`の場合のみ即時切替になります。

Matugen 4.x用テンプレートは`matugen/templates/shirube-colors.json`です。付属の
`matugen/config.example.toml`にある二つの絶対パスを環境に合わせ、使用中のMatugen設定へ
`[templates.shirube]`を追加してください。Matugenが出力ファイルを生成すると自動適用されます。

画面中部のActionは`middle.actions`配列から追加・変更できます。各項目には`symbol`、`name`、
`command`、任意の`enabled`と`size`を指定します。`command`は引数を含む配列を推奨し、文字列を
指定した場合は`sh -c`で実行します。`enabled: false`の項目は表示されません。初期設定の`☯`は
Wofiのdrun、`終`はwlogoutを利用可能な場合に起動します。

### 操作と詳細表示

- ワークスペースと各状態モジュールのHoverフィードバック
- ワークスペースのクリック切替（Niri / Hyprland）
- CPU・Memory・Audio・Networkのクリック展開
- 時刻クリックによる当月カレンダー展開と今日の発光表示
- クリック元付近へ表示し、画面上下からはみ出さないOverlay
- Audio詳細の縦型音量ゲージとミュート切替
- 同じモジュールの再クリック、領域外への移動、IPCによる収納
- 光のフェード領域に対するマウス入力透過

### 光場とレイアウト

- 詳細Overlayの実寸と補正後の位置を光場への入力として使用
- CPU・Memory・Audio・Networkごとに異なる局所的な膨らみ
- 縦位置関数 `width(y)` により、通常光そのものの減衰距離が滑らかに変形する光場
- 展開・収納・モジュール切替時の位置／幅／高さ補間
- 通常時と展開時を一枚の連続した光場として描画
- 64pxのexclusive zoneと光領域の入力透過を維持
- 通常UIを低密度のFloating hologramとして描画
- 詳細情報は背景面や外周を持たず、光場へ直接浮かぶ投影として構成

ウィンドウ配置から確保する幅は `config.json` の `layout.exclusiveZoneWidth`、
通常モジュールの目安幅、光場の描画幅、補間時間は
`compactSurfaceWidth`、`expandedSurfaceWidth`、`interactionMs` から変更できます。

通常モジュールの微細な浮遊は`appearance.floatingEnabled`で切り替え、
`floatingAmplitude`で移動量、`floatingPeriodMs`で基準周期を変更できます。入力領域は動かさず、
描画済みレイヤーの移動変換だけを使うため、浮遊によるCanvasの継続的な再描画は行いません。
`appearance.ambientAnimationEnabled`では、浮遊と光場の呼吸・波をまとめて無効化できます。

光場右端の波は`appearance.lightWaveEnabled`で切り替え、`lightWaveAmplitude`、
`lightWavePeriodMs`、`lightWaveFps`で振幅・周期・更新頻度を変更できます。左端の光源位置は
動かさず、右側の減衰距離だけを低頻度で更新します。`lightFieldStripHeight`は光場の描画密度で、
既定値は見た目と負荷の釣り合いを取った`5`、波の更新頻度は`10`fpsです。小さくすると滑らかさ、
大きくすると軽さを
優先できます（設定範囲は`1`〜`6`）。

起動時は左端から通常の光場が伸び、その途中からモジュール群が静かに浮かび上がります。
光の展開時間は`animation.startupLightMs`、モジュール表示開始までの時間は
`startupUiDelayMs`、表示時間は`startupUiMs`で調整できます。`animation.enabled`が
`false`の場合は起動演出も無効になります。

`appearance.audioReactionEnabled`を有効にすると、PipeWireの既定出力を2kHzモノラルで監視し、
強く平滑化した実音声レベルで光場が数pxだけ緩くたわみます。音声波形やスペクトラムは表示せず、
取得できない環境では自動的に静止状態になります。反応量は`audioReactionStrength`で調整できます。
既定値は穏やかな膨張を視認できる`0.90`です。明るくなるまでの追従時間は
`audioReactionAttackMs`、暗く戻る時間は`audioReactionReleaseMs`で調整できます。
既定値はそれぞれ`90`msと`380`msです。音声レベル自体も50ms間隔で解析します。
旧設定の`audioReactionSmoothingMs`も互換用に保持しています。
変形量とは独立した音声反応時の
光量は`audioReactionBrightness`で調整でき、既定値は`1.35`です。

音声RMS解析は`helpers/shirube-audio-rms`があればバイナリPCMを直接処理します。ビルドは
`sh helpers/build.sh`（または`make -C helpers`）で行え、PipeWire開発ヘッダーは不要です。
未ビルドの場合も`od`と`awk`を使う
互換経路へ自動的にフォールバックします。

状態取得周期は`updates`で用途別に調整できます。`audioMs`、`networkMs`、`batteryMs`を
指定できます。`audioMs`を省略した既存設定では`desktopMs`が互換用の既定値になります。ワークスペースは
イベント駆動を優先し、連続イベントをまとめたうえで`workspaceFallbackMs`でも補完します。

### 性能を考慮した演出

- 入力領域を動かさない低コストなモジュール浮遊
- 連続位相で波打つ光場右端と、設定可能な描画密度
- PipeWire実音声の平滑化レベルによる穏やかな光場反応
- Matugenから差し替え可能な色設定
- 状態取得周期の用途別分離
- コンポジタイベントの短時間集約による不要なプロセス起動の抑制
- 展開操作を最優先にするAmbient・Audio演出の優先度制御
- `animation.enabled`による全アニメーションと音声解析の一括停止

### 性能計測参考値

Radeon RX 6600系・単一出力環境で、通常表示を8〜10秒計測した参考値です。CPU値は1コアを
100%としたShirubeプロセス単体、GPU値はデスクトップ全体のデバイスbusy値です。

- 最適化前（24fps・3px）：CPU `26.8%`
- 波停止時：CPU `4.8%`
- 最終設定（10fps・5px・音声反応有効）：CPU `11.5%`
- RSS：平均約`171 MiB`、観測最大約`172 MiB`
- GPU全体：平均`5%`、最小`1%`、最大`13%`（Shirube以外を含む）

## ライセンス

Shirubeは[MIT License](LICENSE)で公開しています。改変・再配布・商用利用が可能ですが、
ライセンス本文に記載されているとおり、無保証で提供されます。
