defmodule RatchetTest do
  use ExUnit.Case, async: true
  doctest Crypt.Ratchet

  require Crypt.Ratchet

  require Logger

  test "next_chain_key/1" do
    chain_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")

    key_test = "B88B85AFF9E6039891E35C82F426915E6E1D90088481BE6238B47AFED1131DCC"
    outkey_test = "3BD7F5B1EC8BA060909FE0C2000BE2C929BAF8D373F0595090E56D3727789879"
    iv_test = "F20D166279BEA4E5EE36D96630D72253"

    {key, outkey, iv} = Crypt.Ratchet.next_chain_key(chain_key)

    assert byte_size(key) == 32
    assert byte_size(outkey) == 32
    assert byte_size(iv) == 16
    assert Base.encode16(key) == key_test
    assert Base.encode16(outkey) == outkey_test
    assert Base.encode16(iv) == iv_test
  end

  test "ratchet_init/3" do
    root_key = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
    ratchet = %{root_key: root_key, child_key: nil, iv_key: nil}

    private_key =
      Base.decode16!("D0AFC93C994CE9052E02E7BB060E8C892ED83F5A0E231972D7197C5133CC3C78")

    keypair = %{public: nil, private: private_key}

    foreign_public_key =
      Base.decode16!("BEE069055DE66E1D2FDE416917412CE4E173B6B8E18FFECFA04FCB513858ED37")

    root_key_test = "E7ECAB3D408A11764BFEC9FBCD233E45E63B61F0887627DD3885E2E88F44AAC7"
    child_key_test = "070943F0FE16B6A0DCFDE3359CF5610D33138C4F63E1AEC874A6CE47483AF609"

    new_ratchet = Crypt.Ratchet.ratchet_init(ratchet, keypair, foreign_public_key)

    assert byte_size(new_ratchet.root_key) == 32
    assert byte_size(new_ratchet.child_key) == 32
    assert ratchet.iv_key == nil

    assert Base.encode16(new_ratchet.root_key) == root_key_test
    assert Base.encode16(new_ratchet.child_key) == child_key_test
  end

  test "ratchet_cycle/1" do
    ratchet_key =
      Base.decode16!("095EF827044D3BCF62CD65A88764DEC0EB5F6D76FA89FFEE26757FDCABB156AD")

    ratchet_key_1_test = "8DF0759220E9E5EDA23548737AD84F5885A828E44CA31111BA1ED5D71A9D2999"
    child_key_1_test = "A6889EDC5A6C325B93468FC0967FE5F699B613BAAF73ECB0D1375A571D7844C0"
    iv_key_1_test = "2FA50608C2DC7E662E4D1362EAC33A69"

    ratchet_1 = Crypt.Ratchet.ratchet_cycle(ratchet_key)

    assert byte_size(ratchet_1.root_key) == 32
    assert byte_size(ratchet_1.child_key) == 32
    assert byte_size(ratchet_1.iv_key) == 16

    assert Base.encode16(ratchet_1.root_key) == ratchet_key_1_test
    assert Base.encode16(ratchet_1.child_key) == child_key_1_test
    assert Base.encode16(ratchet_1.iv_key) == iv_key_1_test

    ratchet_key_2_test = "25115207BD01BB8D67B1B619E00A25DC4A0A50DEF1A5437A56D07CDB8FFC4A96"
    child_key_2_test = "D397C016958B0B4F0DBCDC41B9749CAD4F49E7A08FD296F1269302F33CFD399E"
    iv_key_2_test = "29EE48217E59AD9749B34D9487E65838"

    ratchet_2 = Crypt.Ratchet.ratchet_cycle(ratchet_1.root_key)

    assert byte_size(ratchet_2.root_key) == 32
    assert byte_size(ratchet_2.child_key) == 32
    assert byte_size(ratchet_2.iv_key) == 16

    assert Base.encode16(ratchet_2.root_key) == ratchet_key_2_test
    assert Base.encode16(ratchet_2.child_key) == child_key_2_test
    assert Base.encode16(ratchet_2.iv_key) == iv_key_2_test
  end
end
