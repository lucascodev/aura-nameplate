return function(Addon, T)
	local SampleReading = Addon.SampleReading
	local Formats = Addon.HealthFormats

	T.Suite("SampleReading", function()
		T.Test("porcentagem escreve so a porcentagem", function()
			local reading = SampleReading.Health(Formats.PERCENT)

			T.Equals(reading.secondary, nil)
			T.IsTrue(reading.primary:find("%%") ~= nil)
		end)

		T.Test("abreviado escreve so o numero curto", function()
			local reading = SampleReading.Health(Formats.ABBREVIATED)

			T.Equals(reading.secondary, nil)
			T.Equals(reading.primary:find("%%"), nil)
		end)

		--- Separadas, como na leitura de verdade: quem desenha decide se ha uma
		--- barra inteira para espalhá-las ou um ponto so' onde encaixar as duas.
		T.Test("ambos entrega as duas partes separadas", function()
			local reading = SampleReading.Health(Formats.BOTH)

			T.IsTrue(reading.primary ~= nil)
			T.IsTrue(reading.secondary ~= nil)
		end)

		T.Test("formato desconhecido cai na porcentagem", function()
			T.Equals(SampleReading.Health("nada disso").secondary, nil)
		end)
	end)
end
