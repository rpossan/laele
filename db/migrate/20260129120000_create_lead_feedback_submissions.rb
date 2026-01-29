# frozen_string_literal: true

class CreateLeadFeedbackSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :lead_feedback_submissions do |t|
      t.references :google_account, null: false, foreign_key: true
      t.string :lead_id, null: false
      t.string :survey_answer, null: false
      t.string :reason
      t.text :other_reason_comment
      t.string :credit_issuance_decision, null: false

      t.timestamps
    end

    add_index :lead_feedback_submissions,
              %i[google_account_id lead_id],
              unique: true,
              name: "index_lead_feedback_submissions_on_account_and_lead"
    add_index :lead_feedback_submissions, :lead_id
  end
end
