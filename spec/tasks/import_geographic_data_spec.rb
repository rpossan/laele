require "rails_helper"
require "rake"

RSpec.describe "geographic:import rake task" do
  before do
    Rake.application.rake_require "tasks/import_geographic_data"
    Rake::Task.define_task(:environment)
  end

  let(:temp_csv) { Tempfile.new(["geographic_data", ".csv"]) }

  after do
    temp_csv.close
    temp_csv.unlink
  end

  def invoke_task(task_name, env_vars = {})
    env_vars.each { |key, value| ENV[key] = value }
    Rake::Task[task_name].reenable
    Rake.application.invoke_task(task_name)
  end

  describe "importing geographic data" do
    it "imports valid geographic data from CSV" do
      csv_content = <<~CSV
        zip_code,city,county,state,country_code
        90210,Beverly Hills,Los Angeles,CA,US
        10001,New York,New York,NY,US
        75201,Dallas,Dallas,TX,US
      CSV

      temp_csv.write(csv_content)
      temp_csv.rewind

      expect {
        invoke_task("geographic:import_from_csv", "FILE" => temp_csv.path)
      }.to change { AddressGeographicMapping.count }.by(3)

      expect(AddressGeographicMapping.find_by(zip_code: "90210").state).to eq("CA")
      expect(AddressGeographicMapping.find_by(zip_code: "10001").state).to eq("NY")
      expect(AddressGeographicMapping.find_by(zip_code: "75201").state).to eq("TX")
    end

    it "normalizes state codes to uppercase" do
      csv_content = <<~CSV
        zip_code,city,county,state,country_code
        90210,Beverly Hills,Los Angeles,ca,US
      CSV

      temp_csv.write(csv_content)
      temp_csv.rewind

      invoke_task("geographic:import_from_csv", "FILE" => temp_csv.path)

      expect(AddressGeographicMapping.find_by(zip_code: "90210").state).to eq("CA")
    end

    it "skips rows with missing required fields" do
      csv_content = <<~CSV
        zip_code,city,county,state,country_code
        90210,Beverly Hills,Los Angeles,CA,US
        ,New York,New York,NY,US
        75201,Dallas,Dallas,TX,US
      CSV

      temp_csv.write(csv_content)
      temp_csv.rewind

      expect {
        invoke_task("geographic:import_from_csv", "FILE" => temp_csv.path)
      }.to change { AddressGeographicMapping.count }.by(2)
    end

    it "updates existing records" do
      AddressGeographicMapping.create!(
        zip_code: "90210",
        city: "Beverly Hills",
        county: "Los Angeles",
        state: "CA",
        country_code: "US"
      )

      csv_content = <<~CSV
        zip_code,city,county,state,country_code
        90210,Beverly Hills,Los Angeles,CA,US
      CSV

      temp_csv.write(csv_content)
      temp_csv.rewind

      expect {
        invoke_task("geographic:import_from_csv", "FILE" => temp_csv.path)
      }.not_to change { AddressGeographicMapping.count }
    end

    it "defaults country_code to US if not provided" do
      csv_content = <<~CSV
        zip_code,city,county,state
        90210,Beverly Hills,Los Angeles,CA
      CSV

      temp_csv.write(csv_content)
      temp_csv.rewind

      invoke_task("geographic:import_from_csv", "FILE" => temp_csv.path)

      expect(AddressGeographicMapping.find_by(zip_code: "90210").country_code).to eq("US")
    end

    it "exits with error if file does not exist" do
      expect {
        invoke_task("geographic:import_from_csv", "FILE" => "/nonexistent/path/to/file.csv")
      }.to raise_error(SystemExit)
    end
  end

  describe "geographic:clear rake task" do
    it "deletes all geographic data" do
      AddressGeographicMapping.create!(
        zip_code: "90210",
        city: "Beverly Hills",
        county: "Los Angeles",
        state: "CA",
        country_code: "US"
      )

      expect {
        invoke_task("geographic:clear")
      }.to change { AddressGeographicMapping.count }.by(-1)
    end
  end

  describe "geographic:validate rake task" do
    it "validates geographic data integrity" do
      AddressGeographicMapping.create!(
        zip_code: "90210",
        city: "Beverly Hills",
        county: "Los Angeles",
        state: "CA",
        country_code: "US"
      )

      expect {
        invoke_task("geographic:validate")
      }.not_to raise_error
    end
  end
end
