import i18n from '@ohos.i18n';
import { LanguageSetting } from './Enums';

/**
 * 8 语言文案对象：新取词接口 I18n.all(...) 使用。
 * 顺序与国家级设置页语言选项一一对应。
 */
export interface LocalizedText {
  zh: string;      // 简体中文
  zhHant: string;  // 繁體中文
  ja: string;      // 日本語
  ko: string;      // 한국어
  en: string;      // English
  fr: string;      // Français
  de: string;      // Deutsch
  es: string;      // Español
}

/**
 * 集中式术语表：键 → 8 语言文案，保证「相同项翻译一致」。
 * 术语与 windows/Services/Localization.cs 对齐。占位符用 {0} / {1}。
 */
const TERMS: Record<string, LocalizedText> = {
  // ---- 通用 ----
  'common.cancel': { zh: '取消', zhHant: '取消', ja: 'キャンセル', ko: '취소', en: 'Cancel', fr: 'Annuler', de: 'Abbrechen', es: 'Cancelar' },
  'common.save': { zh: '保存', zhHant: '儲存', ja: '保存', ko: '저장', en: 'Save', fr: 'Enregistrer', de: 'Speichern', es: 'Guardar' },
  'common.delete': { zh: '删除', zhHant: '刪除', ja: '削除', ko: '삭제', en: 'Delete', fr: 'Supprimer', de: 'Löschen', es: 'Eliminar' },
  'common.back': { zh: '‹ 返回', zhHant: '‹ 返回', ja: '‹ 戻る', ko: '‹ 뒤로', en: '‹ Back', fr: '‹ Retour', de: '‹ Zurück', es: '‹ Atrás' },
  'common.custom': { zh: '自定义', zhHant: '自訂', ja: 'カスタム', ko: '사용자 지정', en: 'Custom', fr: 'Personnalisé', de: 'Benutzerdefiniert', es: 'Personalizado' },

  // ---- 导航 / 目标 ----
  'nav.goals': { zh: '目标', zhHant: '目標', ja: '目標', ko: '목표', en: 'Goals', fr: 'Objectifs', de: 'Ziele', es: 'Objetivos' },
  'nav.settings': { zh: '设置', zhHant: '設定', ja: '設定', ko: '설정', en: 'Settings', fr: 'Réglages', de: 'Einstellungen', es: 'Ajustes' },
  'goals.empty': { zh: '请先添加一个目标', zhHant: '請先新增一個目標', ja: 'まず目標を追加してください', ko: '먼저 목표를 추가하세요', en: 'Add a goal to start', fr: 'Ajoutez d\'abord un objectif', de: 'Bitte zuerst ein Ziel hinzufügen', es: 'Añada primero un objetivo' },
  'goals.add': { zh: '添加目标', zhHant: '新增目標', ja: '目標を追加', ko: '목표 추가', en: 'Add Goal', fr: 'Ajouter un objectif', de: 'Ziel hinzufügen', es: 'Añadir objetivo' },
  'goals.new': { zh: '新建目标', zhHant: '新建目標', ja: '新規目標', ko: '새 목표', en: 'New Goal', fr: 'Nouvel objectif', de: 'Neues Ziel', es: 'Nuevo objetivo' },
  'goals.edit': { zh: '编辑目标', zhHant: '編輯目標', ja: '目標を編集', ko: '목표 편집', en: 'Edit Goal', fr: 'Modifier l\'objectif', de: 'Ziel bearbeiten', es: 'Editar objetivo' },
  'goals.delete': { zh: '删除目标', zhHant: '刪除目標', ja: '目標を削除', ko: '목표 삭제', en: 'Delete Goal', fr: 'Supprimer l\'objectif', de: 'Ziel löschen', es: 'Eliminar objetivo' },
  'goals.namePlaceholder': { zh: '目标名称', zhHant: '目標名稱', ja: '目標名', ko: '목표 이름', en: 'Goal name', fr: 'Nom de l\'objectif', de: 'Zielname', es: 'Nombre del objetivo' },
  'goals.nameRequired': { zh: '请输入目标名称', zhHant: '請輸入目標名稱', ja: '目標名を入力してください', ko: '목표 이름을 입력하세요', en: 'Enter a goal name', fr: 'Saisissez un nom d\'objectif', de: 'Bitte einen Zielnamen eingeben', es: 'Introduzca un nombre de objetivo' },
  'goals.deleteConfirm': { zh: '删除目标「{0}」？其下所有任务将一并删除。', zhHant: '刪除目標「{0}」？其下所有任務將一併刪除。', ja: '目標「{0}」を削除しますか？配下のすべてのタスクも削除されます。', ko: '목표 "{0}"을(를) 삭제할까요? 아래의 모든 작업도 함께 삭제됩니다.', en: 'Delete "{0}" and all its tasks?', fr: 'Supprimer l\'objectif "{0}" ? Toutes ses tâches seront supprimées.', de: 'Ziel "{0}" löschen? Alle zugehörigen Aufgaben werden entfernt.', es: '¿Eliminar el objetivo "{0}"? Se eliminarán todas sus tareas.' },
  'goals.countingMode': { zh: '进度统计模式', zhHant: '進度統計模式', ja: '進捗の集計方法', ko: '진행률 집계 방식', en: 'Progress counting', fr: 'Mode de calcul', de: 'Progressionszählung', es: 'Recuento de progreso' },
  'goals.countAllTasks': { zh: '全部任务', zhHant: '全部任務', ja: 'すべてのタスク', ko: '모든 작업', en: 'All tasks', fr: 'Toutes les tâches', de: 'Alle Aufgaben', es: 'Todas las tareas' },
  'goals.countLeafTasks': { zh: '仅叶子任务', zhHant: '僅葉子任務', ja: '末端タスクのみ', ko: '리프 작업만', en: 'Leaf tasks only', fr: 'Tâches feuilles uniquement', de: 'Nur Blattaufgaben', es: 'Solo tareas hoja' },

  // ---- 任务 ----
  'tasks.remaining': { zh: '剩余时间', zhHant: '剩餘時間', ja: '残り時間', ko: '남은 시간', en: 'Remaining', fr: 'Temps restant', de: 'Verbleibende Zeit', es: 'Tiempo restante' },
  'tasks.completed': { zh: '已完成 {0} 共 {1} 项', zhHant: '已完成 {0} 共 {1} 項', ja: '完了 {0}/{1}', ko: '완료 {0}/{1}', en: 'Done {0} of {1}', fr: 'Terminés {0}/{1}', de: 'Erledigt {0}/{1}', es: 'Completadas {0}/{1}' },
  'tasks.edit': { zh: '编辑', zhHant: '編輯', ja: '編集', ko: '편집', en: 'Edit', fr: 'Modifier', de: 'Bearbeiten', es: 'Editar' },
  'tasks.addSubtask': { zh: '添加子任务', zhHant: '新增子任務', ja: 'サブタスクを追加', ko: '하위 작업 추가', en: 'Add Subtask', fr: 'Ajouter une sous-tâche', de: 'Unteraufgabe hinzufügen', es: 'Añadir subtarea' },
  'tasks.delete': { zh: '删除任务', zhHant: '刪除任務', ja: 'タスクを削除', ko: '작업 삭제', en: 'Delete Task', fr: 'Supprimer la tâche', de: 'Aufgabe löschen', es: 'Eliminar tarea' },
  'tasks.deleteConfirm': { zh: '删除任务「{0}」？其所有子任务将一并删除。', zhHant: '刪除任務「{0}」？其所有子任務將一併刪除。', ja: 'タスク「{0}」を削除しますか？配下のすべてのサブタスクも削除されます。', ko: '작업 "{0}"을(를) 삭제할까요? 아래의 모든 하위 작업도 함께 삭제됩니다.', en: 'Delete "{0}" and all its subtasks?', fr: 'Supprimer la tâche "{0}" ? Toutes ses sous-tâches seront supprimées.', de: 'Aufgabe "{0}" löschen? Alle zugehörigen Unteraufgaben werden entfernt.', es: '¿Eliminar la tarea "{0}"? Se eliminarán todas sus subtareas.' },
  'tasks.nameRequired': { zh: '请输入任务名称', zhHant: '請輸入任務名稱', ja: 'タスク名を入力してください', ko: '작업 이름을 입력하세요', en: 'Enter a task name', fr: 'Saisissez un nom de tâche', de: 'Bitte einen Aufgabennamen eingeben', es: 'Introduzca un nombre de tarea' },
  'task.namePlaceholder': { zh: '任务名称', zhHant: '任務名稱', ja: 'タスク名', ko: '작업 이름', en: 'Task name', fr: 'Nom de la tâche', de: 'Aufgabenname', es: 'Nombre de la tarea' },
  'task.single': { zh: '单项', zhHant: '單項', ja: '単項目', ko: '단일 항목', en: 'Single', fr: 'Ponctuel', de: 'Einmalig', es: 'Único' },
  'task.progress': { zh: '进度', zhHant: '進度', ja: '進捗', ko: '진행률', en: 'Progress', fr: 'Progression', de: 'Fortschritt', es: 'Progreso' },
  'task.total': { zh: '总量', zhHant: '總量', ja: '合計量', ko: '총량', en: 'Total', fr: 'Quantité totale', de: 'Gesamtmenge', es: 'Cantidad total' },
  'task.current': { zh: '当前', zhHant: '目前', ja: '現在', ko: '현재', en: 'Current', fr: 'Actuel', de: 'Aktuell', es: 'Actual' },
  'task.status': { zh: '状态', zhHant: '狀態', ja: 'ステータス', ko: '상태', en: 'Status', fr: 'Statut', de: 'Status', es: 'Estado' },
  'task.notDone': { zh: '未完成', zhHant: '未完成', ja: '未完了', ko: '미완료', en: 'Not Done', fr: 'Non terminé', de: 'Nicht erledigt', es: 'Sin hacer' },
  'task.halfDone': { zh: '半完成', zhHant: '半完成', ja: '半完了', ko: '반 완료', en: 'Half Done', fr: 'Partiellement terminé', de: 'Teilweise erledigt', es: 'A medias' },
  'task.done': { zh: '完成', zhHant: '完成', ja: '完了', ko: '완료', en: 'Done', fr: 'Terminé', de: 'Erledigt', es: 'Hecho' },
  'task.deleted': { zh: '删除', zhHant: '刪除', ja: '削除', ko: '삭제', en: 'Deleted', fr: 'Supprimé', de: 'Gelöscht', es: 'Eliminado' },
  'task.reminder': { zh: '提醒', zhHant: '提醒', ja: 'リマインダー', ko: '알림', en: 'Reminder', fr: 'Rappel', de: 'Erinnerung', es: 'Recordatorio' },
  'task.color': { zh: '颜色', zhHant: '顏色', ja: 'カラー', ko: '색상', en: 'Color', fr: 'Couleur', de: 'Farbe', es: 'Color' },

  // ---- 重复 / 星期 ----
  'repeat.never': { zh: '不重复', zhHant: '不重複', ja: '繰り返しなし', ko: '반복 없음', en: 'Never', fr: 'Jamais', de: 'Nie', es: 'Nunca' },
  'repeat.daily': { zh: '每天', zhHant: '每天', ja: '毎日', ko: '매일', en: 'Daily', fr: 'Quotidien', de: 'Täglich', es: 'Diario' },
  'repeat.weekly': { zh: '每周', zhHant: '每週', ja: '毎週', ko: '매주', en: 'Weekly', fr: 'Hebdomadaire', de: 'Wöchentlich', es: 'Semanal' },
  'repeat.monthly': { zh: '每月', zhHant: '每月', ja: '毎月', ko: '매월', en: 'Monthly', fr: 'Mensuel', de: 'Monatlich', es: 'Mensual' },
  'repeat.custom': { zh: '自定义', zhHant: '自訂', ja: 'カスタム', ko: '사용자 지정', en: 'Custom', fr: 'Personnalisé', de: 'Benutzerdefiniert', es: 'Personalizado' },
  'weekday.1': { zh: '日', zhHant: '日', ja: '日', ko: '일', en: 'Sun', fr: 'Dim', de: 'So', es: 'Dom' },
  'weekday.2': { zh: '一', zhHant: '一', ja: '月', ko: '월', en: 'Mon', fr: 'Lun', de: 'Mo', es: 'Lun' },
  'weekday.3': { zh: '二', zhHant: '二', ja: '火', ko: '화', en: 'Tue', fr: 'Mar', de: 'Di', es: 'Mar' },
  'weekday.4': { zh: '三', zhHant: '三', ja: '水', ko: '수', en: 'Wed', fr: 'Mer', de: 'Mi', es: 'Mié' },
  'weekday.5': { zh: '四', zhHant: '四', ja: '木', ko: '목', en: 'Thu', fr: 'Jeu', de: 'Do', es: 'Jue' },
  'weekday.6': { zh: '五', zhHant: '五', ja: '金', ko: '금', en: 'Fri', fr: 'Ven', de: 'Fr', es: 'Vie' },
  'weekday.7': { zh: '六', zhHant: '六', ja: '土', ko: '토', en: 'Sat', fr: 'Sam', de: 'Sa', es: 'Sáb' },

  // ---- 主题 ----
  'theme.system': { zh: '跟随系统', zhHant: '跟隨系統', ja: 'システムに従う', ko: '시스템 따르기', en: 'Follow System', fr: 'Suivre le système', de: 'System folgen', es: 'Seguir el sistema' },
  'theme.light': { zh: '亮色', zhHant: '亮色', ja: 'ライト', ko: '라이트', en: 'Light', fr: 'Clair', de: 'Hell', es: 'Claro' },
  'theme.dark': { zh: '暗色', zhHant: '暗色', ja: 'ダーク', ko: '다크', en: 'Dark', fr: 'Sombre', de: 'Dunkel', es: 'Oscuro' },

  // ---- AI 模型显示名 ----
  'ai.model.xiaoyi': { zh: '小艺（盘古，需授权）', zhHant: '小藝（盤古，需授權）', ja: '小芸（盤古、要認可）', ko: '샤오이(판구, 인증 필요)', en: 'Xiaoyi (Pangu, requires auth)', fr: 'Xiaoyi (Pangu, autorisation requise)', de: 'Xiaoyi (Pangu, Autorisierung erforderlich)', es: 'Xiaoyi (Pangu, requiere autorización)' },
  'ai.model.qwen': { zh: '千问', zhHant: '千問', ja: 'Qwen', ko: 'Qwen', en: 'Qwen', fr: 'Qwen', de: 'Qwen', es: 'Qwen' },
  'ai.model.deepseek': { zh: 'DeepSeek', zhHant: 'DeepSeek', ja: 'DeepSeek', ko: 'DeepSeek', en: 'DeepSeek', fr: 'DeepSeek', de: 'DeepSeek', es: 'DeepSeek' },
  'ai.model.chatgpt': { zh: 'ChatGPT', zhHant: 'ChatGPT', ja: 'ChatGPT', ko: 'ChatGPT', en: 'ChatGPT', fr: 'ChatGPT', de: 'ChatGPT', es: 'ChatGPT' },
  'ai.model.yuanbao': { zh: '元宝', zhHant: '元寶', ja: 'Yuanbao', ko: 'Yuanbao', en: 'Yuanbao', fr: 'Yuanbao', de: 'Yuanbao', es: 'Yuanbao' },
  'ai.model.glm': { zh: 'GLM', zhHant: 'GLM', ja: 'GLM', ko: 'GLM', en: 'GLM', fr: 'GLM', de: 'GLM', es: 'GLM' },
  'ai.model.kimi': { zh: 'Kimi', zhHant: 'Kimi', ja: 'Kimi', ko: 'Kimi', en: 'Kimi', fr: 'Kimi', de: 'Kimi', es: 'Kimi' },
  'ai.model.ernie': { zh: '文心', zhHant: '文心', ja: 'ERNIE', ko: 'ERNIE', en: 'ERNIE', fr: 'ERNIE', de: 'ERNIE', es: 'ERNIE' },

  // ---- AI 对话页 ----
  'ai.chatTitle': { zh: 'AI 对话', zhHant: 'AI 對話', ja: 'AI チャット', ko: 'AI 채팅', en: 'AI Chat', fr: 'Chat IA', de: 'KI-Chat', es: 'Chat de IA' },
  'ai.attach': { zh: '附件', zhHant: '附件', ja: '添付', ko: '첨부', en: 'Attach', fr: 'Joindre', de: 'Anhang', es: 'Adjuntar' },
  'ai.input': { zh: '输入消息…', zhHant: '輸入訊息…', ja: 'メッセージを入力…', ko: '메시지 입력…', en: 'Type a message…', fr: 'Saisissez un message…', de: 'Nachricht eingeben…', es: 'Escriba un mensaje…' },
  'ai.send': { zh: '发送', zhHant: '傳送', ja: '送信', ko: '보내기', en: 'Send', fr: 'Envoyer', de: 'Senden', es: 'Enviar' },
  'ai.sending': { zh: 'AI 思考中…', zhHant: 'AI 思考中…', ja: 'AI が考え中…', ko: 'AI가 생각 중…', en: 'AI is thinking…', fr: 'L\'IA réfléchit…', de: 'KI denkt nach…', es: 'La IA está pensando…' },
  'ai.attachParseFailed': { zh: '附件解析失败', zhHant: '附件解析失敗', ja: '添付ファイルの解析に失敗', ko: '첨부 파일 분석 실패', en: 'Failed to parse attachment', fr: 'Échec de l\'analyse de la pièce jointe', de: 'Anhang konnte nicht analysiert werden', es: 'Error al analizar el adjunto' },
  'ai.requestFailed': { zh: '请求失败', zhHant: '請求失敗', ja: 'リクエストに失敗', ko: '요청 실패', en: 'Request failed', fr: 'Échec de la requête', de: 'Anfrage fehlgeschlagen', es: 'Error en la solicitud' },
  'ai.done': { zh: '已完成生成', zhHant: '已完成產生', ja: '生成が完了しました', ko: '생성 완료', en: 'Done', fr: 'Génération terminée', de: 'Generierung abgeschlossen', es: 'Generación completada' },

  // ---- AI / 附件 / 备份错误 ----
  'ai.error.notAuthorized': { zh: '小艺（盘古）通道尚未接入：缺少华为开发者证书与 AGC 授权。', zhHant: '小藝（盤古）通道尚未接入：缺少華為開發者憑證與 AGC 授權。', ja: '小芸（盤古）チャネルは未接続です：華為開発者証明書と AGC 認可が必要です。', ko: '샤오이(판구) 채널이 아직 연동되지 않았습니다: 화웨이 개발자 인증서와 AGC 인증이 필요합니다.', en: 'The Xiaoyi (Pangu) channel is not integrated yet: a Huawei developer certificate and AGC authorization are required.', fr: 'Le canal Xiaoyi (Pangu) n\'est pas encore intégré : un certificat de développeur Huawei et une autorisation AGC sont requis.', de: 'Der Xiaoyi-(Pangu-)Kanal ist noch nicht integriert: Ein Huawei-Entwicklerzertifikat und eine AGC-Autorisierung sind erforderlich.', es: 'El canal Xiaoyi (Pangu) aún no está integrado: se requieren un certificado de desarrollador de Huawei y una autorización de AGC.' },
  'ai.error.empty': { zh: '模型未生成有效内容', zhHant: '模型未產生有效內容', ja: 'モデルが有効な内容を生成しませんでした', ko: '모델이 유효한 내용을 생성하지 못했습니다', en: 'The model returned no valid content', fr: 'Le modèle n\'a produit aucun contenu valide', de: 'Das Modell hat keinen gültigen Inhalt erzeugt', es: 'El modelo no generó contenido válido' },
  'ai.error.notConfigured': { zh: '小艺（盘古）尚未授权，且未配置 OpenAI 兼容 API 的 Base URL / 模型名 / API Key。请在 设置 → AI 模型 中配置后再试。', zhHant: '小藝（盤古）尚未授權，且未設定 OpenAI 相容 API 的 Base URL／模型名稱／API Key。請在 設定 → AI 模型 中設定後再試。', ja: '小芸（盤古）は未認可で、OpenAI 互換 API の Base URL／モデル名／API Key も未設定です。設定 → AI モデル で設定してから再試行してください。', ko: '샤오이(판구)가 인증되지 않았고 OpenAI 호환 API의 Base URL/모델명/API Key도 설정되지 않았습니다. 설정 → AI 모델에서 구성한 후 다시 시도하세요.', en: 'Xiaoyi (Pangu) is not authorized and the OpenAI-compatible API Base URL / model name / API Key are not configured. Configure them in Settings → AI Model and try again.', fr: 'Xiaoyi (Pangu) n\'est pas autorisé et l\'URL de base / le nom du modèle / la clé API de l\'API compatible OpenAI ne sont pas configurés. Configurez-les dans Réglages → Modèle IA puis réessayez.', de: 'Xiaoyi (Pangu) ist nicht autorisiert und die Basis-URL / der Modellname / der API-Schlüssel der OpenAI-kompatiblen API sind nicht konfiguriert. Bitte unter Einstellungen → KI-Modell einrichten und erneut versuchen.', es: 'Xiaoyi (Pangu) no está autorizado y la URL base / el nombre del modelo / la clave API de la API compatible con OpenAI no están configurados. Configúrelos en Ajustes → Modelo de IA y vuelva a intentarlo.' },
  'ai.error.apiKeyMissing': { zh: '请先在 设置 → AI 模型 中填写该模型的 API Key', zhHant: '請先在 設定 → AI 模型 中填寫該模型的 API Key', ja: '先に 設定 → AI モデル でこのモデルの API Key を入力してください', ko: '먼저 설정 → AI 모델에서 이 모델의 API Key를 입력하세요', en: 'Please enter this model\'s API Key in Settings → AI Model first', fr: 'Veuillez d\'abord saisir la clé API de ce modèle dans Réglages → Modèle IA', de: 'Bitte zuerst den API-Schlüssel dieses Modells unter Einstellungen → KI-Modell eingeben', es: 'Introduzca primero la clave API de este modelo en Ajustes → Modelo de IA' },
  'ai.error.baseUrlMissing': { zh: '请先在 设置 → AI 模型 中填写自定义 Base URL', zhHant: '請先在 設定 → AI 模型 中填寫自訂 Base URL', ja: '先に 設定 → AI モデル でカスタム Base URL を入力してください', ko: '먼저 설정 → AI 모델에서 사용자 지정 Base URL을 입력하세요', en: 'Please enter a custom Base URL in Settings → AI Model first', fr: 'Veuillez d\'abord saisir une URL de base personnalisée dans Réglages → Modèle IA', de: 'Bitte zuerst eine benutzerdefinierte Basis-URL unter Einstellungen → KI-Modell eingeben', es: 'Introduzca primero una URL base personalizada en Ajustes → Modelo de IA' },
  'ai.error.httpStatus': { zh: '网络请求失败：HTTP {0}', zhHant: '網路請求失敗：HTTP {0}', ja: 'ネットワーク要求に失敗：HTTP {0}', ko: '네트워크 요청 실패: HTTP {0}', en: 'Network request failed: HTTP {0}', fr: 'Échec de la requête réseau : HTTP {0}', de: 'Netzwerkanfrage fehlgeschlagen: HTTP {0}', es: 'Error en la solicitud de red: HTTP {0}' },
  'ai.error.badResponse': { zh: '模型服务返回了异常响应', zhHant: '模型服務回傳了異常回應', ja: 'モデルサービスが異常な応答を返しました', ko: '모델 서비스가 비정상 응답을 반환했습니다', en: 'The model service returned an unexpected response', fr: 'Le service du modèle a renvoyé une réponse inattendue', de: 'Der Modelldienst hat eine unerwartete Antwort zurückgegeben', es: 'El servicio del modelo devolvió una respuesta inesperada' },
  'ai.generatedCount': { zh: '已为你生成 {0} 个任务。', zhHant: '已為你產生 {0} 個任務。', ja: '{0} 個のタスクを生成しました。', ko: '작업 {0}개를 생성했습니다.', en: 'Generated {0} tasks.', fr: '{0} tâches générées.', de: '{0} Aufgaben generiert.', es: 'Se generaron {0} tareas.' },
  'doc.error.unsupportedFormat': { zh: '当前版本暂仅支持文本 / Markdown 附件（PDF / Word 需第三方解析库）', zhHant: '目前版本暫僅支援文字／Markdown 附件（PDF／Word 需第三方程式庫）', ja: '現在のバージョンはテキスト／Markdown 添付のみ対応しています（PDF／Word にはサードパーティ製ライブラリが必要です）。', ko: '현재 버전은 텍스트/Markdown 첨부만 지원합니다(PDF/Word는 타사 라이브러리가 필요합니다).', en: 'This version only supports text / Markdown attachments (PDF / Word require a third-party library).', fr: 'Cette version ne prend en charge que les pièces jointes texte / Markdown (PDF / Word nécessitent une bibliothèque tierce).', de: 'Diese Version unterstützt nur Text-/Markdown-Anhänge (PDF/Word erfordern eine Drittanbieter-Bibliothek).', es: 'Esta versión solo admite adjuntos de texto / Markdown (PDF / Word requieren una biblioteca de terceros).' },
  'doc.error.unsupportedType': { zh: '暂不支持该文件类型，请使用文本或 Markdown 文档', zhHant: '暫不支援該檔案類型，請使用文字或 Markdown 文件', ja: 'このファイル形式には対応していません。テキストまたは Markdown をご利用ください', ko: '이 파일 형식은 지원되지 않습니다. 텍스트 또는 Markdown을 사용하세요', en: 'This file type is not supported. Please use a text or Markdown document.', fr: 'Ce type de fichier n\'est pas pris en charge. Veuillez utiliser un document texte ou Markdown.', de: 'Dieser Dateityp wird nicht unterstützt. Bitte ein Text- oder Markdown-Dokument verwenden.', es: 'Este tipo de archivo no es compatible. Use un documento de texto o Markdown.' },
  'doc.error.readEmpty': { zh: '无法读取文本内容（文件为空或非文本格式）', zhHant: '無法讀取文字內容（檔案為空或非文字格式）', ja: 'テキスト内容を読み取れません（ファイルが空か非テキスト形式です）', ko: '텍스트 내용을 읽을 수 없습니다(파일이 비어 있거나 텍스트 형식이 아님)', en: 'Cannot read text content (the file is empty or not a text format)', fr: 'Impossible de lire le contenu texte (fichier vide ou format non texte)', de: 'Textinhalt kann nicht gelesen werden (Datei leer oder kein Textformat)', es: 'No se puede leer el contenido de texto (el archivo está vacío o no es de texto)' },
  'doc.error.readFailed': { zh: '无法读取文本内容（请确认文件为 UTF-8 文本 / Markdown 格式）', zhHant: '無法讀取文字內容（請確認檔案為 UTF-8 文字／Markdown 格式）', ja: 'テキスト内容を読み取れません（UTF-8 のテキスト／Markdown 形式か確認してください）', ko: '텍스트 내용을 읽을 수 없습니다(UTF-8 텍스트/Markdown 형식인지 확인하세요)', en: 'Cannot read text content (please ensure the file is UTF-8 text / Markdown)', fr: 'Impossible de lire le contenu texte (vérifiez que le fichier est en texte UTF-8 / Markdown)', de: 'Textinhalt kann nicht gelesen werden (bitte sicherstellen, dass die Datei UTF-8-Text/Markdown ist)', es: 'No se puede leer el contenido de texto (compruebe que el archivo sea texto UTF-8 / Markdown)' },
  'backup.error.invalidJson': { zh: '备份文件内容不是有效的 JSON', zhHant: '備份檔案內容不是有效的 JSON', ja: 'バックアップファイルの内容が有効な JSON ではありません', ko: '백업 파일 내용이 유효한 JSON이 아닙니다', en: 'The backup file is not valid JSON', fr: 'Le contenu du fichier de sauvegarde n\'est pas un JSON valide', de: 'Der Inhalt der Sicherungsdatei ist kein gültiges JSON', es: 'El contenido del archivo de copia de seguridad no es un JSON válido' },
  'backup.error.missingData': { zh: '备份文件缺少数据', zhHant: '備份檔案缺少資料', ja: 'バックアップファイルにデータがありません', ko: '백업 파일에 데이터가 없습니다', en: 'The backup file is missing data', fr: 'Le fichier de sauvegarde manque de données', de: 'In der Sicherungsdatei fehlen Daten', es: 'Al archivo de copia de seguridad le faltan datos' },

  // ---- 提醒 / 倒计时单位 ----
  'reminder.content': { zh: '目标：{0}', zhHant: '目標：{0}', ja: '目標：{0}', ko: '목표: {0}', en: 'Goal: {0}', fr: 'Objectif : {0}', de: 'Ziel: {0}', es: 'Objetivo: {0}' },
  'unit.year': { zh: '年', zhHant: '年', ja: '年', ko: '년', en: 'yr', fr: 'an', de: 'Jahr', es: 'año' },
  'unit.month': { zh: '月', zhHant: '月', ja: 'ヶ月', ko: '개월', en: 'mo', fr: 'mois', de: 'Monat', es: 'mes' },
  'unit.day': { zh: '日', zhHant: '日', ja: '日', ko: '일', en: 'd', fr: 'j', de: 'Tag', es: 'día' },
  'unit.hour': { zh: '时', zhHant: '時', ja: '時間', ko: '시간', en: 'h', fr: 'h', de: 'Std.', es: 'h' },
};

/**
 * 轻量多语言：简体中文 / 繁體中文 / 日本語 / 한국어 / English / Français / Deutsch / Español。
 * - 常规 UI 用 I18n.t(键) 取词（键对应上方集中式术语表，8 语言齐全）。
 * - 需要临时文案时用 I18n.all({...8 语言对象}) 取词。
 * - 存量调用 I18n.L(中文, English) 保持兼容；L 仅含中英两语，其余语言回退中文原文。
 * 语言优先级：设置显式语言 > 跟随系统（读取 @ohos.i18n 系统 locale）。
 */
export class I18n {
  private static language: LanguageSetting = 'system';

  /** 应用启动 / 设置变更时调用 */
  static setLanguage(lang: LanguageSetting): void {
    I18n.language = lang;
  }

  static currentLanguage(): LanguageSetting {
    return I18n.language;
  }

  /** 跟随系统时读取系统 locale，未显式设置时判断当前语言 */
  static detectSystemLang(): LanguageSetting {
    try {
      const sys = i18n.System.getSystemLanguage().toLowerCase();
      if (sys.startsWith('zh')) {
        // 繁体：脚本 hant 或地区 tw/hk/mo；其余按简体
        if (sys.indexOf('hant') >= 0 || sys.indexOf('-tw') >= 0 ||
            sys.indexOf('-hk') >= 0 || sys.indexOf('-mo') >= 0) {
          return 'zh-Hant';
        }
        return 'zh';
      }
      if (sys.startsWith('ja')) {
        return 'ja';
      }
      if (sys.startsWith('ko')) {
        return 'ko';
      }
      if (sys.startsWith('fr')) {
        return 'fr';
      }
      if (sys.startsWith('de')) {
        return 'de';
      }
      if (sys.startsWith('es')) {
        return 'es';
      }
      if (sys.startsWith('en')) {
        return 'en';
      }
      return 'zh';
    } catch (e) {
      return 'zh';
    }
  }

  /** 实际生效语言：显式设置优先，否则取跟随系统的判定结果 */
  static resolvedLang(): LanguageSetting {
    if (I18n.language !== 'system') {
      return I18n.language;
    }
    return I18n.detectSystemLang();
  }

  /** 是否应显示英文文案（向后兼容旧接口） */
  static isEnglish(): boolean {
    return I18n.resolvedLang() === 'en';
  }

  /** 新取词接口：给定 8 语言对象，按当前语言返回对应译文，未知回退英文 */
  static all(t: LocalizedText): string {
    switch (I18n.resolvedLang()) {
      case 'zh':
        return t.zh;
      case 'zh-Hant':
        return t.zhHant;
      case 'ja':
        return t.ja;
      case 'ko':
        return t.ko;
      case 'fr':
        return t.fr;
      case 'de':
        return t.de;
      case 'es':
        return t.es;
      case 'en':
      default:
        return t.en;
    }
  }

  /**
   * 术语表取词接口（8 语言齐全）：按当前语言返回 t 的译文；可选替换 {0} / {1} / {2} 占位符。
   * 键不存在时原样返回键，便于发现遗漏。
   */
  static t(key: string, a: string = '', b: string = '', c: string = ''): string {
    const text = TERMS[key];
    if (text === undefined) {
      return key;
    }
    return I18n.fill(I18n.all(text), a, b, c);
  }

  /** 占位符替换（{0}/{1}/{2}） */
  private static fill(s: string, a: string, b: string, c: string): string {
    let out = s;
    out = out.split('{0}').join(a);
    out = out.split('{1}').join(b);
    out = out.split('{2}').join(c);
    return out;
  }

  /**
   * 旧取词接口（仅含中英）：en 时返回英文，其余（含中/日/韩/法/德/西）回退中文原文。
   * 保持既有调用不报错，不破坏行为。
   */
  static L(zh: string, en: string): string {
    return I18n.resolvedLang() === 'en' ? en : zh;
  }
}