using System.Collections.ObjectModel;
using Tick.Data;
using Tick.Domain;
using Tick.Models;

namespace Tick.ViewModels;

/// <summary>
/// 主界面 ViewModel：目标列表 + 当前目标任务树 + 进度 + 目标/任务增删改。
/// 数据变更统一通过 <see cref="Reload"/> 从 SQLite 重新读取，保证对象图与库一致。
/// </summary>
public sealed class MainViewModel : ViewModelBase
{
    private readonly GoalRepository _goalRepo;
    private readonly TaskRepository _taskRepo;

    private Goal? _selectedGoal;

    public ObservableCollection<Goal> Goals { get; } = new();

    public Goal? SelectedGoal => _selectedGoal;

    /// <summary>当前目标的一级任务（已按 SortOrder / CreatedAt 排好序）</summary>
    public IReadOnlyList<TaskItem> CurrentTasks
    {
        get
        {
            if (SelectedGoal is null)
                return Array.Empty<TaskItem>();
            return SelectedGoal.Tasks;
        }
    }

    /// <summary>当前目标总进度（按目标统计模式递归计算）</summary>
    public GoalProgress CurrentProgress =>
        SelectedGoal is null ? default : ProgressEngine.GoalProgressOf(SelectedGoal);

    public bool HasSelection => SelectedGoal is not null;

    /// <summary>任务树 / 进度等派生数据变化时发出（视图据此重建树与头部）</summary>
    public event Action? DataChanged;

    public MainViewModel(GoalRepository goalRepo, TaskRepository taskRepo)
    {
        _goalRepo = goalRepo;
        _taskRepo = taskRepo;
    }

    /// <summary>从数据库重新加载全部目标及其任务树，尽量保留当前选中项</summary>
    public void Reload()
    {
        Guid? selectedId = SelectedGoal?.Id;
        Goals.Clear();
        foreach (var goal in _goalRepo.LoadAll())
        {
            _taskRepo.LoadTreeFor(goal);
            Goals.Add(goal);
        }

        var next = Goals.FirstOrDefault(g => g.Id == selectedId) ?? Goals.FirstOrDefault();
        if (!ReferenceEquals(_selectedGoal, next))
        {
            _selectedGoal = next;
            OnPropertyChanged(nameof(SelectedGoal));
        }
        NotifyChanged();
    }

    public void SelectGoal(Goal? goal)
    {
        if (ReferenceEquals(_selectedGoal, goal))
            return;
        _selectedGoal = goal;
        OnPropertyChanged(nameof(SelectedGoal));
        NotifyChanged();
    }

    // ---- 目标 ----

    public Goal NewGoal() => new Goal();

    public void SaveGoal(Goal goal)
    {
        _goalRepo.Save(goal);
        Reload();
    }

    public void DeleteGoal(Goal goal)
    {
        _goalRepo.Delete(goal.Id);
        Reload();
    }

    // ---- 任务 ----

    public void AddRootTask(TaskItem task)
    {
        if (SelectedGoal is null)
            return;
        task.AttachTo(SelectedGoal);
        _taskRepo.Save(task);
        Reload();
    }

    public void AddSubtask(TaskItem child, TaskItem parent)
    {
        child.AttachTo(parent);
        _taskRepo.Save(child);
        Reload();
    }

    public void UpdateTask(TaskItem task)
    {
        _taskRepo.Save(task);
        Reload();
    }

    public void DeleteTask(TaskItem task)
    {
        _taskRepo.Delete(task.Id);
        Reload();
    }

    /// <summary>快速切换完成态：单项任务在 Done/NotDone 间切换；进度任务在 满/空 间切换。</summary>
    public void ToggleTask(TaskItem task)
    {
        // 接管机制：有子任务的父任务由子任务汇总，控件只读，不在此切换
        if (task.HasSubtasks)
            return;

        if (task.Type == TaskType.Single)
        {
            task.Status = task.Status == TaskStatus.Done ? TaskStatus.NotDone : TaskStatus.Done;
        }
        else
        {
            task.CurrentAmount = task.TotalAmount > 0 && task.CurrentAmount < task.TotalAmount
                ? task.TotalAmount
                : 0;
        }

        _taskRepo.Save(task);
        Reload();
    }

    /// <summary>AI 生成的任务树入库（根任务已挂到当前目标）</summary>
    public void ImportGeneratedTasks(IReadOnlyList<TaskItem> roots)
    {
        foreach (var root in roots)
            _taskRepo.Save(root);
        Reload();
    }

    private void NotifyChanged()
    {
        OnPropertyChanged(nameof(CurrentTasks));
        OnPropertyChanged(nameof(CurrentProgress));
        OnPropertyChanged(nameof(HasSelection));
        DataChanged?.Invoke();
    }
}