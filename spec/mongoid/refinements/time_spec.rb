require "spec_helper"

describe Time do
  using Mongoid::Refinements

  describe ".demongoize" do

    after(:all) do
      Mongoid.use_utc = false
      Mongoid.use_activesupport_time_zone = true
    end

    let!(:time) do
      Time.local(2010, 11, 19)
    end

    context "when the time zone is not defined" do

      before do
        Mongoid.use_utc = false
      end

      context "when the local time is not observing daylight saving" do

        let(:time) do
          Time.utc(2010, 11, 19)
        end

        it "returns the local time" do
          expect(Time.demongoize(time).utc_offset).to eq(
            Time.local(2010, 11, 19).utc_offset
          )
        end
      end

      context "when the local time is observing daylight saving" do

        let(:time) do
          Time.utc(2010, 9, 19)
        end

        it "returns the local time" do
          expect(Time.demongoize(time)).to eq(time.getlocal)
        end
      end

      context "when we have a time close to midnight" do

        let(:time) do
          Time.local(2010, 11, 19, 0, 30).utc
        end

        it "changes it back to the equivalent local time" do
          expect(Time.demongoize(time)).to eq(time)
        end
      end

      context "when using the ActiveSupport time zone" do

        before do
          Mongoid.use_activesupport_time_zone = true
          Time.zone = "Stockholm"
        end

        after do
          Time.zone = nil
          Mongoid.use_activesupport_time_zone = false
        end

        it "returns an ActiveSupport::TimeWithZone" do
          expect(Time.demongoize(time).class).to eq(ActiveSupport::TimeWithZone)
        end

        context "when the local time is not observing daylight saving" do

          let(:new_time) do
            Time.utc(2010, 11, 19, 12)
          end

          it "returns the local time" do
            expect(Time.demongoize(new_time)).to eq(
              Time.zone.local(2010, 11, 19, 13)
            )
          end
        end

        context "when the local time is observing daylight saving" do

          let(:new_time) do
            Time.utc(2010, 9, 19, 12)
          end

          it "returns the local time" do
            expect(Time.demongoize(new_time)).to eq(
              Time.zone.local(2010, 9, 19, 14)
            )
          end
        end

        context "when we have a time close to midnight" do

          let(:new_time) do
            Time.utc(2010, 11, 19, 0, 30)
          end

          it "change it back to the equivalent local time" do
            expect(Time.demongoize(new_time)).to eq(
              Time.zone.local(2010, 11, 19, 1, 30)
            )
          end
        end
      end
    end

    context "when the time zone is defined as UTC" do

      before do
        Mongoid.use_utc = true
      end

      after do
        Mongoid.use_utc = false
      end

      it "returns utc" do
        expect(Time.demongoize(time.dup.utc).utc_offset).to eq(0)
      end

      context "when using the ActiveSupport time zone" do

        let(:time) do
          Time.utc(2010, 11, 19, 0, 30)
        end

        before do
          Mongoid.use_activesupport_time_zone = true
          Time.zone = "Stockholm"
        end

        after do
          Time.zone = nil
          Mongoid.use_activesupport_time_zone = false
        end

        it "returns utc" do
          expect(Time.demongoize(time)).to eq(
            ActiveSupport::TimeZone['UTC'].local(2010, 11, 19, 0, 30)
          )
        end

        it "returns an ActiveSupport::TimeWithZone" do
          expect(Time.demongoize(time).class).to eq(
            ActiveSupport::TimeWithZone
          )
        end
      end
    end

    context "when time is nil" do

      it "returns nil" do
        expect(Time.demongoize(nil)).to be_nil
      end
    end
  end

  describe ".mongoize" do

    let!(:time) do
      Time.local(2010, 11, 19)
    end

    context "when given nil" do

      it "returns nil" do
        expect(Time.mongoize(nil)).to be_nil
      end
    end

    context "when string is empty" do

      it "returns nil" do
        expect(Time.mongoize("")).to be_nil
      end
    end

    context "when given a string" do

      context "when the string is a valid time" do

        it "converts to a utc time" do
          expect(Time.mongoize(time.to_s).utc_offset).to eq(0)
        end

        it "serializes with time parsing" do
          expect(Time.mongoize(time.to_s)).to eq(Time.parse(time.to_s).utc)
        end

        it "returns a local date from the string" do
          expect(Time.mongoize(time.to_s)).to eq(
            Time.local(time.year, time.month, time.day, time.hour, time.min, time.sec)
          )
        end
      end

      context "when the string is an invalid time" do

        let(:epoch) do
          Time.utc(1970, 1, 1, 0, 0, 0, 0)
        end

        it "converts the time to epoch" do
          expect(Time.mongoize("time")).to eq(epoch)
        end
      end

      context "when using the ActiveSupport time zone" do

        before do
          Mongoid.use_activesupport_time_zone = true
          # if this is actually your time zone, the following tests are useless
          Time.zone = "Stockholm"
        end

        after do
          Time.zone = nil
          Mongoid.use_activesupport_time_zone = false
        end

        context "when the local time is not observing daylight saving" do

          it "returns the local time" do
            expect(Time.mongoize('2010-11-19 5:00:00')).to eq(
              Time.utc(2010, 11, 19, 4)
            )
          end
        end

        context "when the local time is observing daylight saving" do

          it "returns the local time" do
            expect(Time.mongoize('2010-9-19 5:00:00')).to eq(
              Time.utc(2010, 9, 19, 3)
            )
          end
        end
      end
    end

    context "when given a DateTime" do

      let!(:time) do
        DateTime.now
      end

      let!(:eom_time) do
        DateTime.parse("2012-11-30T23:59:59.999999999-05:00")
      end

      let!(:eom_time_mongoized) do
        eom_time.mongoize
      end

      it "doesn't strip milli- or microseconds" do
        expect(Time.mongoize(time).to_f).to eq(time.to_time.to_f)
      end

      it "doesn't round up the hour at end of month" do
        expect(eom_time_mongoized.hour).to eq(eom_time.utc.hour)
      end

      it "doesn't round up the minute" do
        expect(eom_time_mongoized.min).to eq(eom_time.utc.min)
      end

      it "doesn't round up the seconds" do
        expect(eom_time_mongoized.sec).to eq(eom_time.utc.sec)
      end

      it "does not alter seconds" do
        expect((eom_time_mongoized.usec)).to eq(999999)
      end

      it "does not alter seconds with fractions" do
        expect(DateTime.mongoize(11.11).to_f).to eq(11.11)
      end

      context "when using the ActiveSupport time zone" do

        let(:datetime) do
          DateTime.new(2010, 11, 19)
        end

        before do
          Mongoid.use_activesupport_time_zone = true
          # if this is actually your time zone, the following tests are useless
          Time.zone = "Stockholm"
        end

        after do
          Time.zone = nil
          Mongoid.use_activesupport_time_zone = false
        end

        it "assumes the given time is local" do
          expect(Time.mongoize(datetime)).to eq(
            Time.utc(2010, 11, 19)
          )
        end

        it "doesn't round up the hour" do
          expect(eom_time_mongoized.hour).to eq(eom_time.utc.hour)
        end

        it "doesn't round up the minutes" do
          expect(eom_time_mongoized.min).to eq(eom_time.utc.min)
        end

        it "doesn't round up the seconds" do
          expect(eom_time_mongoized.sec).to eq(eom_time.utc.sec)
        end

        it "does not alter the seconds" do
          expect((eom_time_mongoized.usec)).to eq(999999)
        end
      end
    end

    context "when given a Time" do

      it "converts to a utc time" do
        expect(Time.mongoize(time).utc_offset).to eq(0)
      end

      it "returns utc times unchanged" do
        expect(Time.mongoize(time.utc)).to eq(time.utc)
      end

      it "returns the time as utc" do
        expect(Time.mongoize(time)).to eq(time.utc)
      end

      it "doesn't strip milli- or microseconds" do
        expect(Time.mongoize(time).to_f).to eq(time.to_f)
      end

      it "does not alter seconds with fractions" do
        expect(Time.mongoize(102.63).to_f).to eq(102.63)
      end
    end

    context "when given an ActiveSupport::TimeWithZone" do

      before do
        1.hour.ago
      end

      it "converts it to utc" do
        expect(Time.mongoize(time.in_time_zone("Alaska"))).to eq(
          Time.at(time.to_i).utc
        )
      end
    end

    context "when given a Date" do

      let(:date) do
        Date.today
      end

      it "converts to a utc time" do
        expect(Time.mongoize(date)).to eq(Time.local(date.year, date.month, date.day))
      end

      it "has a zero utc offset" do
        expect(Time.mongoize(date).utc_offset).to eq(0)
      end

      context "when using the ActiveSupport time zone" do

        let(:date) do
          Date.new(2010, 11, 19)
        end

        before do
          Mongoid.use_activesupport_time_zone = true
          # if this is actually your time zone, the following tests are useless
          Time.zone = "Stockholm"
        end

        after do
          Time.zone = nil
          Mongoid.use_activesupport_time_zone = false
        end

        it "assumes the given time is local" do
          expect(Time.mongoize(date)).to eq(Time.utc(2010, 11, 18, 23))
        end
      end
    end

    context "when given an array" do

      let(:array) do
        [ 2010, 11, 19, 00, 24, 49 ]
      end

      it "returns a time" do
        expect(Time.mongoize(array)).to eq(Time.local(*array))
      end

      context "when using the ActiveSupport time zone" do

        before do
          Mongoid.use_activesupport_time_zone = true
          # if this is actually your time zone, the following tests are useless
          Time.zone = "Stockholm"
        end

        after do
          Time.zone = nil
          Mongoid.use_activesupport_time_zone = false
        end

        it "assumes the given time is local" do
          expect(Time.mongoize(array)).to eq(
            Time.utc(2010, 11, 18, 23, 24, 49)
          )
        end
      end
    end
  end

  describe "#mongoize" do

    let!(:time) do
      Time.local(2010, 11, 19)
    end

    let!(:eom_time) do
      Time.local(2012, 11, 30, 23, 59, 59, 999999.999)
    end

    let!(:eom_time_mongoized) do
      eom_time.mongoize
    end

    it "converts to a utc time" do
      expect(time.mongoize.utc_offset).to eq(0)
    end

    it "returns the time as utc" do
      expect(time.mongoize).to eq(time.utc)
    end

    it "doesn't strip milli- or microseconds" do
      expect(time.mongoize.to_f).to eq(time.to_f)
    end

    it "doesn't round up at end of month" do
      expect(eom_time_mongoized.hour).to eq(eom_time.utc.hour)
      expect(eom_time_mongoized.min).to eq(eom_time.utc.min)
      expect(eom_time_mongoized.sec).to eq(eom_time.utc.sec)
      expect(eom_time_mongoized.usec).to eq(eom_time.utc.usec)
      expect(eom_time_mongoized.subsec.to_f.round(3)).to eq(eom_time.utc.subsec.to_f.round(3))
    end
  end

  describe ".evolve" do

    context "when provided a time" do

      context "when the time is not in utc" do

        let(:date) do
          Time.new(2010, 1, 1, 12, 0, 0)
        end

        let(:evolved) do
          described_class.evolve(date)
        end

        let(:expected) do
          Time.new(2010, 1, 1, 12, 0, 0).utc
        end

        it "returns the same time" do
          expect(evolved).to eq(expected)
        end

        it "returns the time in utc" do
          expect(evolved.utc_offset).to eq(0)
        end
      end

      context "when the time is already utc" do

        let(:date) do
          Time.new(2010, 1, 1, 12, 0, 0).utc
        end

        let(:evolved) do
          described_class.evolve(date)
        end

        let(:expected) do
          Time.new(2010, 1, 1, 12, 0, 0).utc
        end

        it "returns the same time" do
          expect(evolved).to eq(expected)
        end

        it "returns the time in utc" do
          expect(evolved.utc_offset).to eq(0)
        end
      end
    end

    context "when provided an array" do

      context "when the array is composed of times" do

        let(:date) do
          Time.new(2010, 1, 1, 12, 0, 0)
        end

        let(:evolved) do
          described_class.evolve([ date ])
        end

        let(:expected) do
          Time.new(2010, 1, 1, 12, 0, 0).utc
        end

        it "returns the array with evolved times" do
          expect(evolved).to eq([ expected ])
        end

        it "returns utc times" do
          expect(evolved.first.utc_offset).to eq(0)
        end
      end

      context "when the array is composed of strings" do

        let(:date) do
          Time.parse("1st Jan 2010 12:00:00+01:00")
        end

        let(:evolved) do
          described_class.evolve([ date.to_s ])
        end

        it "returns the strings as a times" do
          expect(evolved).to eq([ date.to_time ])
        end

        it "returns the times in utc" do
          expect(evolved.first.utc_offset).to eq(0)
        end
      end

      context "when the array is composed of integers" do

        let(:integer) do
          1331890719
        end

        let(:evolved) do
          described_class.evolve([ integer ])
        end

        let(:expected) do
          Time.at(integer).utc
        end

        it "returns the integers as times" do
          expect(evolved).to eq([ expected ])
        end

        it "returns the times in utc" do
          expect(evolved.first.utc_offset).to eq(0)
        end
      end

      context "when the array is composed of floats" do

        let(:float) do
          1331890719.413
        end

        let(:evolved) do
          described_class.evolve([ float ])
        end

        let(:expected) do
          Time.at(float).utc
        end

        it "returns the floats as times" do
          expect(evolved).to eq([ expected ])
        end

        it "returns the times in utc" do
          expect(evolved.first.utc_offset).to eq(0)
        end
      end
    end

    context "when provided a range" do

      context "when the range are dates" do

        let(:min) do
          Time.new(2010, 1, 1, 12, 0, 0)
        end

        let(:max) do
          Time.new(2010, 1, 3, 12, 0, 0)
        end

        let(:evolved) do
          described_class.evolve(min..max)
        end

        let(:expected_min) do
          Time.new(2010, 1, 1, 12, 0, 0).utc
        end

        let(:expected_max) do
          Time.new(2010, 1, 3, 12, 0, 0).utc
        end

        it "returns a selection of times" do
          expect(evolved).to eq(
                                 { "$gte" => expected_min, "$lte" => expected_max }
                             )
        end

        it "returns the times in utc" do
          expect(evolved["$gte"].utc_offset).to eq(0)
        end
      end

      context "when the range are strings" do

        let(:min) do
          Time.new(2010, 1, 1, 12, 0, 0)
        end

        let(:max) do
          Time.new(2010, 1, 3, 12, 0, 0)
        end

        let(:evolved) do
          described_class.evolve(min.to_s..max.to_s)
        end

        it "returns a selection of times" do
          expect(evolved).to eq(
                                 { "$gte" => min.to_time, "$lte" => max.to_time }
                             )
        end

        it "returns the times in utc" do
          expect(evolved["$gte"].utc_offset).to eq(0)
        end
      end

      context "when the range is floats" do

        let(:min) do
          1331890719.1234
        end

        let(:max) do
          1332890719.7651
        end

        let(:evolved) do
          described_class.evolve(min..max)
        end

        let(:expected_min) do
          Time.at(min).utc
        end

        let(:expected_max) do
          Time.at(max).utc
        end

        it "returns a selection of times" do
          expect(evolved).to eq(
                                 { "$gte" => expected_min, "$lte" => expected_max }
                             )
        end

        it "returns the times in utc" do
          expect(evolved["$gte"].utc_offset).to eq(0)
        end
      end

      context "when the range is integers" do

        let(:min) do
          1331890719
        end

        let(:max) do
          1332890719
        end

        let(:evolved) do
          described_class.evolve(min..max)
        end

        let(:expected_min) do
          Time.at(min).utc
        end

        let(:expected_max) do
          Time.at(max).utc
        end

        it "returns a selection of times" do
          expect(evolved).to eq(
                                 { "$gte" => expected_min, "$lte" => expected_max }
                             )
        end

        it "returns the times in utc" do
          expect(evolved["$gte"].utc_offset).to eq(0)
        end
      end
    end

    context "when provided a string" do

      let(:date) do
        Time.parse("1st Jan 2010 12:00:00+01:00")
      end

      let(:evolved) do
        described_class.evolve(date.to_s)
      end

      it "returns the string as a time" do
        expect(evolved).to eq(date.to_time)
      end

      it "returns the time in utc" do
        expect(evolved.utc_offset).to eq(0)
      end
    end

    context "when provided a float" do

      let(:float) do
        1331890719.8170738
      end

      let(:evolved) do
        described_class.evolve(float)
      end

      let(:expected) do
        Time.at(float)
      end

      it "returns the float as a time" do
        expect(evolved).to eq(expected)
      end

      it "returns the time in utc" do
        expect(evolved.utc_offset).to eq(0)
      end
    end

    context "when provided an integer" do

      let(:integer) do
        1331890719
      end

      let(:evolved) do
        described_class.evolve(integer)
      end

      let(:expected) do
        Time.at(integer)
      end

      it "returns the integer as a time" do
        expect(evolved).to eq(expected)
      end

      it "returns the time in utc" do
        expect(evolved.utc_offset).to eq(0)
      end
    end

    context "when provided nil" do

      it "returns nil" do
        expect(described_class.evolve(nil)).to be_nil
      end
    end
  end

  describe "#__evolve_date__" do

    let(:time) do
      Time.new(2010, 1, 1, 12, 0, 0)
    end

    let(:evolved) do
      time.__evolve_date__
    end

    it "returns midnight utc" do
      expect(evolved).to eq(Time.utc(2010, 1, 1, 0, 0, 0))
    end
  end

  describe "#__evolve_time__" do

    let(:time) do
      Time.new(2010, 1, 1, 12, 0, 0)
    end

    let(:evolved) do
      time.__evolve_time__
    end

    it "returns self as utc" do
      expect(evolved).to eq(Time.new(2010, 1, 1, 12, 0, 0).utc)
    end
  end
end