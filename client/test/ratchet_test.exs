defmodule RatchetTester do
  use ExUnit.Case, async: true
  doctest Crypt.Ratchet

  require Crypt.Ratchet

  require Logger

  test "rk_cycle/3" do
    root_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
    ratchet = %{root_key: root_key, child_key: nil}

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    keypair = %{public: nil, private: private_key}

    foreign_public_key =
      Base.decode16!("BEE069055DE66E1D2FDE416917412CE4E173B6B8E18FFECFA04FCB513858ED37")

    root_key_test = "D1254098A5CB664F492D3D08922EFB8A4C6BB8135DD6E3D93D93954A9A392745"
    child_key_test = "DA174E441D97DECD6D78FE3542BCBABCE22BE25BEFDDBF4E4369CC68CFBC0C44"

    new_ratchet = Crypt.Ratchet.rk_cycle(ratchet, keypair, foreign_public_key)

    assert byte_size(new_ratchet.root_key) == 32
    assert byte_size(new_ratchet.child_key) == 32

    assert Base.encode16(new_ratchet.root_key) == root_key_test
    assert Base.encode16(new_ratchet.child_key) == child_key_test
  end

  test "ck_cycle/1" do
    ratchet_key =
      Base.decode16!("095EF827044D3BCF62CD65A88764DEC0EB5F6D76FA89FFEE26757FDCABB156AD")

    ratchet_key_1_test = "E92EEE7911A8356841CAB50778B6F20CF9CD6569398973AE48DB7D9F33A05F62"
    child_key_1_test = "FA0C39F434C4F36BBF9A084EFEFD75311F7E4E9EB3F2722C5991BA556CE7A48E"

    ratchet_1 = Crypt.Ratchet.ck_cycle(ratchet_key)

    assert byte_size(ratchet_1.root_key) == 32
    assert byte_size(ratchet_1.child_key) == 32

    assert Base.encode16(ratchet_1.root_key) == ratchet_key_1_test
    assert Base.encode16(ratchet_1.child_key) == child_key_1_test

    ratchet_key_2_test = "B355CEA56E018CEBF6133ED751286B1889EA8F419238591007A18F1A94B72107"
    child_key_2_test = "9F51ECD5D3F9B203C7A3EEC0BD04C57D9B71A3EE72E1889C8596719F353A27D2"

    ratchet_2 = Crypt.Ratchet.ck_cycle(ratchet_1.root_key)

    assert byte_size(ratchet_2.root_key) == 32
    assert byte_size(ratchet_2.child_key) == 32

    assert Base.encode16(ratchet_2.root_key) == ratchet_key_2_test
    assert Base.encode16(ratchet_2.child_key) == child_key_2_test
  end
end
