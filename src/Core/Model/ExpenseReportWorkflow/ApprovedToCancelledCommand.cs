using ClearMeasure.Bootcamp.Core.Features.Workflow;

namespace ClearMeasure.Bootcamp.Core.Model.ExpenseReportWorkflow
{
    public class ApprovedToCancelledCommand : StateCommandBase
    {
        public ApprovedToCancelledCommand() : base()
        {
        }

        protected override void preExecute(ExecuteTransitionCommand transitionCommand)
        {
            transitionCommand.Report.LastCancelled =
                transitionCommand.Report.LastWithdrawn = transitionCommand.CurrentDate;
        }

        public override string TransitionVerbPresentTense
        {
            get { return "Withdraw and Cancel"; }
        }

        public override string TransitionVerbPastTense
        {
            get { return "Withdrawn and Cancelled"; }
        }

        public override ExpenseReportStatus GetBeginStatus()
        {
            return ExpenseReportStatus.Approved;
        }

        protected override ExpenseReportStatus GetEndStatus()
        {
            return ExpenseReportStatus.Cancelled;
        }

        protected override bool userCanExecute(Employee currentUser, ExpenseReport report)
        {
            return currentUser == report.Submitter;
        }
    }
}