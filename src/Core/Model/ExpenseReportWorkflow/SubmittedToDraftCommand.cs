using ClearMeasure.Bootcamp.Core.Features.Workflow;
using ClearMeasure.Bootcamp.Core.Services;
namespace ClearMeasure.Bootcamp.Core.Model.ExpenseReportWorkflow
{
    public class SubmittedToDraftCommand : StateCommandBase
    {
        public SubmittedToDraftCommand()
            : base()
        {
        }

        public override string TransitionVerbPresentTense
        {
            get { return "Withdraw"; }
        }

        public override string TransitionVerbPastTense
        {
            get { return "Withdrawn"; }
        }

        public override ExpenseReportStatus GetBeginStatus()
        {
            return ExpenseReportStatus.Submitted;
        }

        protected override ExpenseReportStatus GetEndStatus()
        {
            return ExpenseReportStatus.Draft;
        }

        protected override bool userCanExecute(Employee currentUser, ExpenseReport report)
        {
            return currentUser == report.Submitter;
        }

        protected override void preExecute(ExecuteTransitionCommand transitionCommand)
        {
            transitionCommand.Report.LastWithdrawn = transitionCommand.CurrentDate;
        }
    }
}
