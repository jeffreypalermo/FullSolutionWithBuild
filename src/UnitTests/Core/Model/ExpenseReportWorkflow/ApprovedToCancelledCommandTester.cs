using System;
using ClearMeasure.Bootcamp.Core.Features.Workflow;
using ClearMeasure.Bootcamp.Core.Model;
using ClearMeasure.Bootcamp.Core.Model.ExpenseReportWorkflow;
using ClearMeasure.Bootcamp.Core.Services;
using NUnit.Framework;
using Rhino.Mocks;

namespace ClearMeasure.Bootcamp.UnitTests.Core.Model.ExpenseReportWorkflow
{
    [TestFixture]
    public class ApprovedToCancelledCommandTester : StateCommandBaseTester
    {
        [Test]
        public void ShouldSetLastWithdrawnAndCancelledTime()
        {
            var order = new ExpenseReport();
            order.Number = "123";
            order.Status = ExpenseReportStatus.Approved;
            var employee = new Employee();
            order.Approver = employee;

            var cancelledDate = new DateTime(2015, 01, 01);

            var command = new ApprovedToCancelledCommand();

            command.Execute(new ExecuteTransitionCommand(order, null, employee, cancelledDate));

            Assert.That(order.LastCancelled, Is.EqualTo(cancelledDate));
            Assert.That(order.LastWithdrawn, Is.EqualTo(cancelledDate));

            var cancelledDate2 = new DateTime(2015, 02, 02);

            var command2 = new ApprovedToCancelledCommand();
            command2.Execute(new ExecuteTransitionCommand(order, null, employee, cancelledDate2));

            Assert.That(order.LastCancelled, Is.Not.EqualTo(cancelledDate));
            Assert.That(order.LastCancelled, Is.EqualTo(cancelledDate2));
        }
        

        [Test]
        public void ShouldNotBeValidInWrongStatus()
        {
            var order = new ExpenseReport();
            order.Status = ExpenseReportStatus.Submitted;
            var employee = new Employee();
            order.Submitter = employee;

            var command = new ApprovedToCancelledCommand();
            Assert.That(command.IsValid(new ExecuteTransitionCommand{Report = order, CurrentUser = employee}), Is.False);
        }

        [Test]
        public void ShouldNotBeValidWithWrongEmployee()
        {
            var order = new ExpenseReport();
            order.Status = ExpenseReportStatus.Approved;
            var employee = new Employee();
            var differentEmployee = new Employee();
            var approver = new Employee();
            order.Submitter = employee;
            order.Approver = approver;

            var command = new ApprovedToCancelledCommand();
            Assert.That(command.IsValid(new ExecuteTransitionCommand { Report = order, CurrentUser = approver }), Is.False);

            var command2 = new ApprovedToCancelledCommand();
            Assert.That(command2.IsValid(new ExecuteTransitionCommand { Report = order, CurrentUser = differentEmployee }), Is.False);
        }

        [Test]
        public void ShouldBeValid()
        {
            var order = new ExpenseReport();
            order.Status = ExpenseReportStatus.Approved;
            var employee = new Employee();
            order.Submitter = employee;

            var command = new ApprovedToCancelledCommand();
            Assert.That(command.IsValid(new ExecuteTransitionCommand { Report = order, CurrentUser = employee }), Is.True);
        }

        [Test]
        public void ShouldTransitionStateProperly()
        {
            var order = new ExpenseReport();
            order.Number = "123";
            order.Status = ExpenseReportStatus.Approved;
            var employee = new Employee();
            order.Submitter = employee;

            var command = new ApprovedToCancelledCommand();
            command.Execute(new ExecuteTransitionCommand(order, null, employee, new DateTime()));

            Assert.That(order.Status, Is.EqualTo(ExpenseReportStatus.Cancelled));
        }

        protected override StateCommandBase GetStateCommand(ExpenseReport order, Employee employee)
        {
            return new ApprovedToCancelledCommand();
        }
    }
}