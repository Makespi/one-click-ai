import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/config_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

/// Wizard step 3: Configuration form for API provider and model settings.
class StepConfigure extends StatefulWidget {
  const StepConfigure({super.key});

  @override
  State<StepConfigure> createState() => _StepConfigureState();
}

class _StepConfigureState extends State<StepConfigure> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _opusController = TextEditingController();
  final _sonnetController = TextEditingController();
  final _haikuController = TextEditingController();
  bool _showApiKey = false;
  bool _showAdvanced = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromConfig());
  }

  void _prefillFromConfig() {
    if (_prefilled) return;
    final config = context.read<ConfigProvider>();
    final profile = config.profile;

    if (profile.apiKey != null && profile.apiKey!.isNotEmpty) {
      _apiKeyController.text = profile.apiKey!;
    }
    if (profile.baseUrl != null && profile.baseUrl!.isNotEmpty) {
      _baseUrlController.text = profile.baseUrl!;
    }
    if (profile.opusModelId != null && profile.opusModelId!.isNotEmpty) {
      _opusController.text = profile.opusModelId!;
    }
    if (profile.sonnetModelId != null && profile.sonnetModelId!.isNotEmpty) {
      _sonnetController.text = profile.sonnetModelId!;
    }
    if (profile.haikuModelId != null && profile.haikuModelId!.isNotEmpty) {
      _haikuController.text = profile.haikuModelId!;
    }

    _prefilled = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _opusController.dispose();
    _sonnetController.dispose();
    _haikuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final wizard = context.read<WizardProvider>();

    // Update wizard proceed state based on API key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      wizard.setCanProceed(config.profile.apiKey?.isNotEmpty == true);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Claude Code already installed banner
          if (wizard.claudeAlreadyInstalled)
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.check_circle,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Claude Code 已安装',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.primaryLight,
                                )),
                        const SizedBox(height: 2),
                        Text('已跳过安装步骤，可直接配置或更新 API 设置',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

          if (wizard.claudeAlreadyInstalled) const SizedBox(height: 16),

          // Existing config banner
          if (config.hasExistingConfig)
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.folder_open,
                        size: 18, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('检测到已有配置',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.success,
                                )),
                        const SizedBox(height: 2),
                        Text('已从现有设置中预填表单',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

          if (config.hasExistingConfig) const SizedBox(height: 20),

          Text(
            '配置 API 服务',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '配置 Claude Code 的 API 连接信息和模型偏好',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // API Provider selector
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API 服务商',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                _ProviderOption(
                  label: 'DeepSeek',
                  subtitle: 'api.deepseek.com/anthropic',
                  isSelected: config.providerType == ApiProviderType.deepseek,
                  onTap: () {
                    config.setProviderType(ApiProviderType.deepseek);
                    _updateControllers(config);
                  },
                ),
                const SizedBox(height: 8),
                _ProviderOption(
                  label: 'Anthropic 官方',
                  subtitle: 'api.anthropic.com',
                  isSelected: config.providerType == ApiProviderType.anthropic,
                  onTap: () {
                    config.setProviderType(ApiProviderType.anthropic);
                    _updateControllers(config);
                  },
                ),
                const SizedBox(height: 8),
                _ProviderOption(
                  label: '自定义',
                  subtitle: '自定义 API 端点',
                  isSelected: config.providerType == ApiProviderType.custom,
                  onTap: () {
                    config.setProviderType(ApiProviderType.custom);
                    _updateControllers(config);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // API Key
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Key',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  onChanged: config.setApiKey,
                  decoration: InputDecoration(
                    hintText: '输入您的 API Key',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _showApiKey = !_showApiKey),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Base URL (for custom provider)
          if (config.providerType == ApiProviderType.custom) ...[
            const SizedBox(height: 24),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Base URL',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlController,
                    onChanged: config.setBaseUrl,
                    decoration: const InputDecoration(
                      hintText: 'https://api.example.com/anthropic',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Advanced: Model configuration
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              children: [
                Icon(
                  _showAdvanced
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  '高级设置 - 模型配置',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),

          if (_showAdvanced) ...[
            const SizedBox(height: 16),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模型 ID 映射',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '设置各模型的完整 ID，留空则使用默认值',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _modelField('Opus', _opusController, config.setOpusModelId,
                      config.profile.opusModelId),
                  const SizedBox(height: 12),
                  _modelField('Sonnet', _sonnetController, config.setSonnetModelId,
                      config.profile.sonnetModelId),
                  const SizedBox(height: 12),
                  _modelField('Haiku', _haikuController, config.setHaikuModelId,
                      config.profile.haikuModelId),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _updateControllers(ConfigProvider config) {
    _baseUrlController.text = config.profile.baseUrl ?? '';
    _opusController.text = config.profile.opusModelId ?? '';
    _sonnetController.text = config.profile.sonnetModelId ?? '';
    _haikuController.text = config.profile.haikuModelId ?? '';
  }

  Widget _modelField(
    String label,
    TextEditingController controller,
    Function(String) onChanged,
    String? placeholder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: placeholder ?? '默认模型',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ProviderOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
