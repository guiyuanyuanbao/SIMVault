import 'package:flutter/material.dart';

class KeepAlivePage extends StatelessWidget {
  const KeepAlivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知保活设置', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '为了确保哪怕把后台上划退出也能准时收到过期提醒，请务必完成以下两步设置。这套极致保活机制结合了系统闹钟特权与底层白名单。',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 30),
          _buildStepCard(
            context,
            step: '1',
            title: '下拉锁定后台 (防手滑清理)',
            content: '在手机屏幕底部上划进入「最近任务/后台管理」界面，找到 SIMVault 卡片，向下滑动（或长按）直到出现一把「小锁」图标。这样就算点击一键清理，应用也不会被杀掉。',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 20),
          _buildStepCard(
            context,
            step: '2',
            title: '允许后台运行 (打破系统休眠)',
            content: '进入系统的「应用启动管理」或「电池优化」设置。\n\n1. 找到 SIMVault，关闭「自动管理」\n2. 开启「允许自启动」\n3. 开启「允许关联启动」\n4. 开启「允许后台活动」',
            icon: Icons.battery_charging_full_rounded,
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            '🛡️ SIMVault 极致保活架构说明',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            '本应用已在底层全面升级了极客级保活机制，彻底摆脱系统限制：\n\n'
            '• 前台守护进程 (Foreground Service)：应用启动后会自动开启底层的持久化守护进程。哪怕你在多任务界面把应用“上滑强杀”，守护进程也会在几秒内浴火重生，继续在后台默默为你守候，确保系统不会清理掉你的闹钟。\n'
            '• 全屏意图轰炸 (FullScreenIntent)：已启用安卓最高级别的打扰权限。哪怕手机屏幕锁定，也能强行亮屏并将通知送到你的眼前。\n'
            '• 闹钟级调度 (AlarmClock)：彻底抛弃普通后台任务，直接调用系统核心闹钟服务。只要时间一到，就像早晨起床的闹钟一样具有绝对特权。\n'
            '• 深度防挂起 (WAKE_LOCK & DirectBootAware)：在底层植入了唤醒锁，并允许在设备刚重启且未解锁时就开始运行。这保证了即使在深度休眠状态，应用也能瞬间拿到 CPU 算力。\n'
            '• 原生广播接收器：配合上述手动白名单，哪怕你在后台把应用彻底划掉，底层时间到达时，系统依然会通过广播将我们的核心通知硬核拉起！',
            style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, {required String step, required String title, required String content, required IconData icon, Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Icon(icon, color: Theme.of(context).colorScheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
          if (action != null) ...[
            const SizedBox(height: 20),
            Center(child: action),
          ]
        ],
      ),
    );
  }
}
