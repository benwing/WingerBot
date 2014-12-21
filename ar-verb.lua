--[[
 
Author: User:Benwing, from early version by User:Atitarev, User:ZxxZxxZ
 
Todo:
 
1. Finish unimplemented conjugation types. Only IX-final-weak left (extremely
   rare, possibly only one verb اِعْمَايَ (according to Haywood and Nahmad p. 244,
   who are very specific about the irregular occurrence of alif + yā instead
   of expected اِعْمَيَّ with doubled yā). Not in Hans Wehr.
2. Implement irregular verbs as special cases and recognize them, e.g.
   -- laysa "to not be"; only exists in the past tense, no non-past, no
      imperative, no participles, no passive, no verbal noun. Irregular
      alternation las-/lays-.
   -- ḥayya/ḥayiya yaḥyā "live" -- behaves like a normal final-weak verb
      (e.g. past first singular ḥayītu) except in the past-tense forms with
      vowel-initial endings (all the third person except for the third feminine
      plural). The normal singular and dual endings have -yiya- in them, which
      compresses to -yya-, with the normal endings the less preferred ones.
      In masculine third plural, expected ḥayū is replaced by ḥayyū by
      analogy to the -yy- forms, and the regular form is not given as an
      alternant in John Mace. Barron's 201 verbs appears to have the regular
      ḥayū as the form, however. Note also that final -yā appears with tall
      alif. This appears to be a spelling convention of Arabic, also applying
      in ḥayyā (form II, "to keep (someone) alive") and 'aḥyā (form IV,
      "to animate, revive, give birth to, give new life to").
   -- `ayya/`ayiya ya`ayyu/ya`yā "to not find the right way, be incapable of,
       stammer, falter, fall ill". This appears to be a mixture of a geminate
       and final-weak verb. Unclear what the whole paradigm looks like. Do
       the consonant-ending forms in the past follow the final-weak paradigm?
       Is it the same in the non-past? Or can you conjugate the non-past
       fully as either geminate or final-weak?
3. Implement individual override parameters for each form. See Module:fro-verb
   for an example of how to do this generally. Note that {{temp|ar-conj-I}}
   and other of the older templates already have such individual override
   params.
4. Edit ar-verb so that quadriliteral verbs also go into
   [Category:Arabic verbs with quadriliteral roots],
   which also contains things like [Category:Arabic form-Iq verbs].

Irregular verbs already implemented:

   -- [istaḥā yastaḥī "be ashamed of" -- this is complex according to Hans Wehr
      because there are two verbs, regular istaḥyā yastaḥyī "to spare
      (someone)'s life" and irregular istaḥyā yastaḥyī "to be ashamed to face
      (someone)", which is irregular because it has the alternate irregular
      form istaḥā yastaḥī which only applies to this meaning. Presumably we
      need a special parameter to handle this. However, given that e.g.
      Haywood and Nahmad don't make the distinction between the two kinds and
      say that both varieties can be spelled istaḥyā/istaḥā/istaḥḥā, we should
      maybe do the same.] -- implemented the easier way, not distinguishing the
      two meanings and allowing the alternates for both.
   -- [ittaxadha yattaxidhu "take"] -- implemented
   -- [sa'ala yas'alu "ask" with alternative jussive/imperative yasal/sal] -- implemented
   -- [ra'ā yarā "see"] -- implemented
   -- ['arā yurī "show"] -- implemented
   -- ['akala ya'kulu "eat" with imperative kul] -- implemented
   -- ['axadha ya'xudhu "take" with imperative xudh] -- implemented
   -- ['amara ya'muru "order" with imperative mur] -- implemented

--]]

local m_utilities = require("Module:utilities")
local m_links = require("Module:links")
local ar_translit = require("Module:ar-translit")

local lang = require("Module:languages").getByCode("ar")
local curtitle = mw.title.getCurrentTitle().fullText
local yesno = require("Module:yesno")

local rfind = mw.ustring.find
local rsub = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local usub = mw.ustring.sub
local ulen = mw.ustring.len

local export = {}

-- Within this module, conjugations are the functions that do the actual
-- conjugating by creating the forms of a basic verb.
-- They are defined further down.
local conjugations = {}
local dia = {
	s = "\217\146",
	a = "\217\142",
	i = "\217\144",
	u = "\217\143",
	an = "\217\139",
	in_ = "\217\141",
	un = "\217\140",
	sh = "\217\145",
	sh_a = "\217\142\217\145",
	sh_i = "\217\144\217\145",
	sh_u = "\217\143\217\145"
	}
local alif = "ا"
local amaq = "ى" -- alif maqṣūra
local yaa = "ي"
local waw = "و"
local taa = "ت"
local siin = "س"
local nuun = "ن"
local hamza = "ء"
local hamza_on_alif = "أ"
local hamza_under_alif = "إ"
local hamza_on_waw = "ؤ"
local hamza_on_yaa = "ئ"
local amad = "آ" -- alif madda
local ma = "م" .. dia.a
local mu = "م" .. dia.u
local aa = dia.a .. alif
local aamaq = dia.a .. amaq
local ah = dia.a .. "ة"
local aah = aa .. "ة"
local ii = dia.i .. yaa
local uu = dia.u .. waw
local ay = dia.a .. yaa
local aw = dia.a .. waw
local hamza_subst = "\239\191\176" -- Unicode U+FFF0

--------------------
-- Utility functions
--------------------

-- "if not empty" -- convert empty strings to nil; also strip quotes around
-- strings, to allow embedded spaces to be included
local function ine(x)
	if x == nil then
		return nil
	elseif rfind(x, '^".*"$') then
		local ret = rmatch(x, '^"(.*)"$')
		return ret
	elseif rfind(x, "^'.*'$") then
		local ret = rmatch(x, "^'(.*)'$")
		return ret
	elseif x == "" then
		return nil
	else
		return x
	end
end

-- true if array contains item
local function contains(tab, item)
	for _, value in pairs(tab) do
		if value == item then
			return true
		end
	end
	return false
end

-- append to array if element not already present
local function insert_if_not(tab, item)
	if not contains(tab, item) then
		table.insert(tab, item)
	end
end

-- version of rsub() that discards all but the first return value
function rsub1(term, foo, bar)
	local retval = rsub(term, foo, bar)
	return retval
end

local function links(text)
	if word == "" or word == "&mdash;" then
		return word
	else
		return m_links.language_link(text, nil, lang, nil, curtitle)
	end
end

local function tag_text(text, tag, class)
	return m_links.full_link(nil, text, lang, nil, nil, nil, {["tr"] = "-"}, curtitle)
end

---------------------------------------
-- Properties of different verbal forms
---------------------------------------

local numeric_to_roman_form = {
	["1"] = "I", ["2"] = "II", ["3"] = "III", ["4"] = "IV", ["5"] = "V",
	["6"] = "VI", ["7"] = "VII", ["8"] = "VIII", ["9"] = "IX", ["10"] = "X",
	["11"] = "XI", ["12"] = "XII", ["13"] = "XIII", ["14"] = "XIV", ["15"] = "XV",
	["1q"] = "Iq", ["2q"] = "IIq", ["3q"] = "IIIq", ["4q"] = "IVq"
}

-- convert numeric form to roman-numeral form
local function canonicalize_form(form)
	return numeric_to_roman_form[form] or form
end

local function form_supports_final_weak(form)
	return form ~= "XI" and form ~= "XV" and form ~= "IVq"
end

local function form_supports_geminate(form)
	return form == "I" or form == "III" or form == "IV" or
		form == "VI" or form == "VII" or form == "VIII" or form == "X"
end

local function form_supports_hollow(form)
	return form == "I" or form == "IV" or form == "VII" or form == "VIII" or
		form == "X"
end

local function form_probably_impersonal_passive(form)
	return form == "VI"
end

local function form_probably_no_passive(form, weakness, past_vowel, nonpast_vowel)
	return form == "I" and weakness ~= "hollow" and contains(past_vowel, "u") or
		form == "VII" or form == "IX" or form == "XI" or form == "XII" or
		form == "XIII" or form == "XIV" or form == "XV" or form == "IIq" or
		form == "IIIq" or form == "IVq"
end

---------------------------------------------------
-- Radicals associated with various irregular verbs
---------------------------------------------------

-- Form-I verb أخذ or form-VIII verb اتخذ
local function axadh_radicals(rad1, rad2, rad3)
	return rad1 == hamza and rad2 == "خ" and rad3 == "ذ"
end

-- Form-I verb whose imperative has a reduced form: أكل and أخذ and أمر
local function reduced_imperative_verb(rad1, rad2, rad3)
	return axadh_radicals(rad1, rad2, rad3) or rad1 == hamza and (
		rad2 == "ك" and rad3 == "ل" or
		rad2 == "م" and rad3 == "ر")
end

-- Form-I verb رأى and form-IV verb أرى
local function raa_radicals(rad1, rad2, rad3)
	return rad1 == "ر" and rad2 == hamza and rad3 == yaa
end

-- Form-I verb سأل
local function saal_radicals(rad1, rad2, rad3)
	return rad1 == "س" and rad2 == hamza and rad3 == "ل"
end

-- Form-I verb حيّ or حيي and form-X verb استحيا or استحى or يستحّى
local function hayy_radicals(rad1, rad2, rad3)
	return rad1 == "ح" and rad2 == yaa and rad3 == yaa
end

-----------------------------
-- Main conjugation functions
-----------------------------

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local origargs = frame:getParent().args
	local args = {}
	-- Convert empty arguments to nil, and "" or '' arguments to empty
	for k, v in pairs(origargs) do
		args[k] = ine(v)
	end
	
	local conj_type = args[1] or frame.args[1] or
		error("Conjugation type has not been specified. Please pass parameter 1 to the template or module invocation.")

	local data, form, weakness, past_vowel, nonpast_vowel = conjugate(args, 2, conj_type)
	
	-- if the value is "impers", the verb has only impersonal passive;
	-- if the value is "yes" or variants, verb has a passive;
	-- if the value is "no" or variants, the verb has no passive.
	-- If not specified, default is yes, but no for forms VII, IX,
	-- XII - XV and IIq - IVq, and "impers" for form VI.
	local passive = args["passive"]
	if passive == "impers" then
	elseif not passive then
		passive = form_probably_impersonal_passive(form) and "impers" or
			not form_probably_no_passive(form, weakness, past_vowel,
				nonpast_vowel) and true or false
	else
		passive = yesno(passive, "unknown")
		if passive == "unknown" then
			error("Unrecognized value '" .. args["passive"] ..
				"' to argument passive=; use 'impers', 'yes'/'y'/'true'/'1' or 'no'/'n'/'false'/'0'")
		end
	end
	if passive == "impers" then
		table.insert(data.categories, "Arabic verbs with impersonal passive")
	elseif passive then
		table.insert(data.categories, "Arabic verbs with full passive")
	else
		table.insert(data.categories, "Arabic verbs with no passive")
	end

	-- if the value is "yes" or variants, the verb is intransitive;
	-- if the value is "no" or variants, the verb is transitive.
	-- If not specified, default is intransitive if passive == false or
	-- passive == "impers", else transitive.
	local intrans = args["intrans"]
	if not intrans then
		intrans = passive == false or passive == "impers" and true or false
	else
		intrans = yesno(intrans, "unknown")
		if intrans == "unknown" then
			error("Unrecognized value '" .. args["intrans"] ..
				"' to argument intrans=; use 'yes'/'y'/'true'/'1' or 'no'/'n'/'false'/'0'")
		end
	end
	if intrans then
		table.insert(data.categories, "Arabic intransitive verbs")
	else
		table.insert(data.categories, "Arabic transitive verbs")
	end

	-- initialize title, with weakness indicated by conjugation
	-- (FIXME should it be by form?)
	local title = "form-" .. form .. " " .. weakness

	if data.irregular then
		table.insert(data.categories, "Arabic irregular verbs")
		title = title .. " irregular"
	end

	return make_table(data, title, passive, intrans) ..
		m_utilities.format_categories(data.categories, lang)
	-- for testing forms only, comment out the line above and
	-- uncomment to see all forms with their names
	--return test_forms(data, title)
end

-- Version of main entry point meant for calling from the debug console.
function export.show2(args, parargs)
	local frame = {args = args, getParent = function() return {args = parargs} end}
	return export.show(frame)
end

-- Guts of conjugation functions. Shared between {{temp|ar-conj}} and
-- {{temp|ar-verb}}. ARGS is the frame parent arguments, ARGIND is the index
-- of the first numbered argument after any verb-form argument, and
-- CONJ_TYPE is the value of the verb-form argument.
function conjugate(args, argind, conj_type)
	local data = {forms = {}, categories = {}, headword_categories = {}}

	-- check to see if an argument ends in a ?. If so, strip the ? and return
	-- true. Otherwise, return false.
	local function check_for_uncertainty(arg)
		if args[arg] and rfind(args[arg], "%?$") then
			args[arg] = rsub(args[arg], "%?$", "")
			if args[arg] == "" then
				args[arg] = nil
			end
			return true
		else
			return false
		end
	end

	-- allow a ? at the end of vn= and passive=; if so, putting the page into
	-- special categories indicating the need to check the property in
	-- question, and remove the ?.
	if check_for_uncertainty("vn") then
		table.insert(data.categories, "Arabic verbs needing verbal noun checked")
	end
	if check_for_uncertainty("passive") then
		table.insert(data.categories, "Arabic verbs needing passive checked")
	end

	PAGENAME = mw.title.getCurrentTitle().text
	NAMESPACE = mw.title.getCurrentTitle().nsText

	-- derive form and weakness from conj type
	local form, weakness
	if rfind(conj_type, "%-") then
		local form_weakness = rsplit(conj_type, "%-")
		assert(#form_weakness == 2)
		form = form_weakness[1]
		weakness = form_weakness[2]
	else
		form = conj_type
		weakness = nil
	end
	
	-- convert numeric forms to Roman numerals
	form = canonicalize_form(form)
	
	-- check for quadriliteral form (Iq, IIq, IIIq, IVq)
	local quadlit = rmatch(form, "q$")
	
	-- get radicals and past/non-past vowel
	local rad1, rad2, rad3, rad4, past_vowel, nonpast_vowel
	if form == "I" then
		past_vowel = args[argind + 0]
		nonpast_vowel = args[argind + 1]
		local function splitvowel(vowelspec)
			if vowelspec == nil then
				vowelspec = {}
			else
				vowelspec = rsplit(vowelspec, ",")
			end
			return vowelspec
		end
		-- allow multiple past or non-past vowels separated by commas, e.g.
		-- in farada/faruda yafrudu "to be single"
		past_vowel = splitvowel(past_vowel)
		nonpast_vowel = splitvowel(nonpast_vowel)
		rad1 = args[argind + 2] or args["I"]
		rad2 = args[argind + 3] or args["II"]
		rad3 = args[argind + 4] or args["III"]
	else
		rad1 = args[argind + 0] or args["I"]
		rad2 = args[argind + 1] or args["II"]
		rad3 = args[argind + 2] or args["III"]
		if quadlit then
			rad4 = args[argind + 3] or args["IV"]
		end
	end

	-- Default any unspecified radicals to radicals determined from the
	-- headword. The return radicals may have Latin letters in them (w, t, y)
	-- to indicate ambiguous radicals that should be converted to the
	-- corresponding Arabic letters.
	--
	-- Only call infer_radicals() if at least one radical unspecified,
	-- because infer_radicals() will throw an error if the headword is
	-- malformed for the form, and we don't want that to happen (e.g. we might
	-- be called from a test page).
	if not rad1 or not rad2 or not rad3 or quadlit and not rad4 then
		local wkness, r1, r2, r3, r4 =
			export.infer_radicals(PAGENAME, form)
		-- Use the inferred weakness if we don't override any of the inferred
		-- radicals with something else, i.e. for each user-specified radical,
		-- either it's nil (was not specified) or same as inferred radical.
		-- That way we will correctly set the weakness to sound in cases like
		-- layisa "to be valiant", 'aḥwaja "to need", istahwana "to consider easy",
		-- izdawaja "to be in pairs", etc.
		local use_wkness = (not rad1 or rad1 == r1) and (not rad2 or rad2 == r2) and
			(not rad3 or rad3 == r3) and (not rad4 or rad4 == r4)
		rad1 = rad1 or r1
		rad2 = rad2 or r2
		rad3 = rad3 or r3
		rad4 = rad4 or r4

		-- For most ambiguous radicals, the choice of radical doesn't matter
		-- because it doesn't affect the conjugation one way or another.
		-- For form I hollow verbs, however, it definitely does. In fact, the
		-- choice of radical is critical even beyond the past and non-past
		-- vowels because it affects the form of the passive participle.
		-- So, check for this, try to guess if necessary from non-past vowel,
		-- else signal an error, requiring that the radical be specified
		-- explicitly. This will happen when the non-past vowel isn't specified
		-- and also when it's "a", from which the radical cannot be inferred.
		-- Do this check here rather than in infer_radicals() so that we don't
		-- get an error if the appropriate radical is given but not others.
		if form == "I" and (rad2 == "w" or rad2 == "y") then
			if contains(nonpast_vowel, "i") then
				rad2 = yaa
			elseif contains(nonpast_vowel, "u") then
				rad2 = waw
			else
				error("Unable to guess middle radical of hollow form I verb; " ..
					"need to specify radical explicitly")
			end
		end

		-- If weakness unspecified, then maybe default to weakness determined
		-- from headword. We do this specifically when some radicals are
		-- unspecified and all specified radicals are the same as the
		-- corresponding inferred radicals, i.e. the specified radicals (if any)
		-- don't provide any new information. When this isn't the case, and
		-- the specified radicals override the inferred radicals with something
		-- else, the inferred weakness may be wrong, so we figure out
		-- the weakness below by ourselves, based on the combination of any
		-- user-specified and inferred radicals.
		--
		-- The reason for using the inferred weakness when possible is that
		-- it may be more accurate than the weakness we derive below, in
		-- particular with verbs like layisa "to be courageous",
		-- `awira "to be one-eyed", 'aḥwaja "to need", istajwaba "to interrogate",
		-- izdawaja "to be in pairs", with a weak vowel in a sound conjugation.
		-- The weakness derived below from the radicals would be hollow but the
		-- weakness inferred in infer_radicals() is (correctly) sound.
		if use_wkness then
			weakness = weakness or wkness
		end
	end

	-- Create headword categories based on the radicals. Do the following before
	-- converting the Latin radicals into Arabic ones so we don't create
	-- categories based on ambiguous radicals.
	if rad1 == waw or rad1 == yaa or rad1 == hamza then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. rad1 .. " as first radical")
	end
	if rad2 == waw or rad2 == yaa or rad2 == hamza then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. rad2 .. " as second radical")
	end
	if rad3 == waw or rad3 == yaa or rad3 == hamza then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. rad3 .. " as third radical")
	end
	
	-- Convert the Latin radicals indicating ambiguity into the corresponding
	-- Arabic radicals.
	local function regularize_inferred_radical(rad)
		if rad == "t" then
			return taa
		elseif rad == "w" then
			return waw
		elseif rad == "y" then
			return yaa
		else
			return rad
		end
	end

	rad1 = regularize_inferred_radical(rad1)
	rad2 = regularize_inferred_radical(rad2)
	rad3 = regularize_inferred_radical(rad3)
	rad4 = regularize_inferred_radical(rad4)
	
	-- Old code, default radicals to ف-ع-ل or variants.
	
	--if not quadlit then
	--	-- default radicals to ف-ع-ل (or ف-ل-ل for geminate, or with the
	--	-- appropriate radical replaced by waw for assimilated/hollow/final-weak)
	--	rad1 = rad1 or
	--		(weakness == "assimilated" or weakness == "assimilated+final-weak") and waw or "ف"
	--	rad2 = rad2 or weakness == "hollow" and waw or
	--		weakness == "geminate" and "ل" or "ع"
	--	rad3 = rad3 or (weakness == "final-weak" or weakness == "assimilated+final-weak") and waw or
	--		weakness == "geminate" and rad2 or "ل"
	--else
	--	-- default to ف-ع-ل-ق (or ف-ع-ل-و for final-weak)
	--	rad1 = rad1 or "ف"
	--	rad2 = rad2 or "ع"
	--	rad3 = rad3 or "ل"
	--	rad4 = rad4 or weakness == "final-weak" and waw or "ق"
	--end

	-- If weakness unspecified, derive from radicals.
	if not quadlit then
		if weakness == nil then
			if is_waw_yaa(rad3) and rad1 == waw and form == "I" then
				weakness = "assimilated+final-weak"
			elseif is_waw_yaa(rad3) and form_supports_final_weak(form) then
				weakness = "final-weak"
			elseif rad2 == rad3 and form_supports_geminate(form) then
				weakness = "geminate"
			elseif is_waw_yaa(rad2) and form_supports_hollow(form) then
				weakness = "hollow"
			elseif rad1 == waw and form == "I" then
				weakness = "assimilated"
			else
				weakness = "sound"
			end
		end
	else
		if weakness == nil then
			if is_waw_yaa(rad4) then
				weakness = "final-weak"
			else
				weakness = "sound"
			end
		end
	end

	-- Error if radicals are wrong given the weakness. More likely to happen
	-- if the weakness is explicitly given rather than inferred. Will also
	-- happen if certain incorrect letters are included as radicals e.g.
	-- hamza on top of various letters, alif maqṣūra, tā' marbūṭa.
	check_radicals(form, weakness, rad1, rad2, rad3, rad4)

	-- Initialize categories related to form and weakness.
	initialize_categories(data.categories, data.headword_categories,
		form, weakness, rad1, rad2, rad3, rad4)

	-- Reconstruct conjugation type from form and (possibly inferred) weakness.
	conj_type = form .. "-" .. weakness

	-- Check that the conjugation type is recognized.
	if not conjugations[conj_type] then
		error("Unknown conjugation type '" .. conj_type .. "'")
	end

	-- Actually conjugate the verb. The signature of the conjugation function
	-- is different for form-I verbs, non-form-I triliteral verbs, and
	-- quadriliteral verbs.
	--
	-- The way the conjugation functions work is they always add entries to the
	-- appropriate forms of the paradigm (each of which is an array), rather
	-- than setting the values. This makes it possible to call more than one
	-- conjugation function and essentially get a paradigm of the "either
	-- A or B" kind. Doing this may insert duplicate entries into a particular
	-- paradigm form, but this is not a problem because we remove duplicate
	-- entries (in get_spans()) before generating the actual table.
	if quadlit then
		conjugations[conj_type](data, args, rad1, rad2, rad3, rad4)
	elseif form ~= "I" then
		conjugations[conj_type](data, args, rad1, rad2, rad3)
	else
		-- For Form-I verbs, we also pass in the past and non-past vowels.
		-- There may be more than one of each in case of alternative possible
		-- conjugations. In such cases, we loop over the sets of vowels,
		-- calling the appropriate conjugation function for each combination
		-- of past and non-past vowel.

		-- If the past or non-past vowel is unspecified, its value will be
		-- an empty array. In such a case, we still want to iterate once,
		-- passing in nil. Ideally, we'd convert empty arrays into one-element
		-- arrays holding the value nil, but Lua doesn't let you put the
		-- value nil into an array. To work around this we convert each array
		-- to an array of one-element arrays and fetch the first item of the
		-- inner array when we encounter it. Corresponding to nil will
		-- be an empty array, and fetching its first item will indeed
		-- return nil.
		local function convert_to_nested_array(array)
			if #array == 0 then
				return {{}}
			else
				local retval = {}
				for _, el in ipairs(array) do
					table.insert(retval, {el})
				end
				return retval
			end
		end
		local pv_nested = convert_to_nested_array(past_vowel)
		local npv_nested = convert_to_nested_array(nonpast_vowel)
		for i, pv in ipairs(pv_nested) do
			for j, npv in ipairs(npv_nested) do
				-- items were made into 1-element arrays so undo this
				conjugations[conj_type](data, args, rad1, rad2, rad3, pv[1], npv[1])
			end
		end
	end

	return data, form, weakness, past_vowel, nonpast_vowel
end

-- Infer radicals from headword and form. Throw an error if headword is
-- malformed. Returned radicals may contain Latin letters "t", "w" or "y"
-- indicating ambiguous radicals guessed to be taa, waw or yaa respectively.
function export.infer_radicals(headword, form)
	local letters = {}
	-- sub out alif-madda for easier processing
	headword = rsub(headword, amad, hamza .. alif)

	local len = ulen(headword)

	-- extract the headword letters into an array
	for i = 1, len do
		table.insert(letters, usub(headword, i, i))
	end
	
	-- check that the letter at the given index is the given string, or
	-- is one of the members of the given array
	local function check(index, must)
		local letter = letters[index]
		if type(must) == "string" then
			if letter == nil then
				error("Letter " .. index .. " is nil")
			end
			if letter ~= must then
				error("For form " .. form .. ", letter " .. index ..
					" must be " .. must .. ", not " .. letter)
			end
		elseif not contains(must, letter) then
			error("For form " .. form .. ", radical " .. index ..
				" must be one of " .. table.concat(must, " ") .. ", not " .. letter)
		end
	end

	-- Check that length of headword is within [min, max]
	local function check_len(min, max)
		if len < min then
			error("Not enough letters in headword " .. headword ..
				" for form " .. form .. ", expected at least " .. min)
		elseif len > max then
			error("Too many letters in headword " .. headword ..
				" for form " .. form .. ", expected at most " .. max)
		end
	end

	local quadlit = rmatch(form, "q$")
	
	-- find first radical, start of second/third radicals, check for
	-- required letters
	local radstart, rad1, rad2, rad3, rad4
	local weakness
	if form == "I" or form == "II" then
		rad1 = letters[1]
		radstart = 2
	elseif form == "III" then
		rad1 = letters[1]
		check(2, alif)
		radstart = 3
	elseif form == "IV" then
		-- this would be alif-madda but we replaced it with hamza-alif above.
		if letters[1] == hamza and letters[2] == alif then
			rad1 = hamza
		else
			check(1, hamza_on_alif)
			rad1 = letters[2]
		end
		radstart = 3
	elseif form == "V" then
		check(1, taa)
		rad1 = letters[2]
		radstart = 3
	elseif form == "VI" then
		check(1, taa)
		if letters[2] == amad then
			rad1 = hamza
			radstart = 3
		else
			rad1 = letters[2]
			check(3, alif)
			radstart = 4
		end
	elseif form == "VII" then
		check(1, alif)
		check(2, nuun)
		rad1 = letters[3]
		radstart = 4
	elseif form == "VIII" then
		check(1, alif)
		rad1 = letters[2]
		if rad1 == taa or rad1 == "د" or rad1 == "ث" or rad1 == "ذ" or rad1 == "ط" or rad1 == "ظ" then
			radstart = 3
		elseif rad1 == "ز" then
			check(3, "د")
			radstart = 4
		elseif rad1 == "ص" or rad1 == "ض"  then
			check(3, "ط")
			radstart = 4
		else
			check(3, taa)
			radstart = 4
		end
		if rad1 == taa then
			-- radical is ambiguous, might be ت or و or ي but doesn't affect
			-- conjugation
			rad1 = "t"
		end
	elseif form == "IX" then
		check(1, alif)
		rad1 = letters[2]
		radstart = 3
	elseif form == "X" then
		check(1, alif)
		check(2, siin)
		check(3, taa)
		rad1 = letters[4]
		radstart = 5
	elseif form == "Iq" then
		rad1 = letters[1]
		rad2 = letters[2]
		radstart = 3
	elseif form == "IIq" then
		check(1, taa)
		rad1 = letters[2]
		rad2 = letters[3]
		radstart = 4
	elseif form == "IIIq" then
		check(1, alif)
		rad1 = letters[2]
		rad2 = letters[3]
		check(4, nuun)
		radstart = 5
	elseif form == "IVq" then
		check(1, alif)
		rad1 = letters[2]
		rad2 = letters[3]
		radstart = 4
	elseif form == "XI" then
		check_len(5, 5)
		check(1, alif)
		rad1 = letters[2]
		rad2 = letters[3]
		check(4, alif)
		rad3 = letters[5]
		weakness = "sound"
	elseif form == "XII" then
		check(1, alif)
		rad1 = letters[2]
		if letters[3] ~= letters[5] then
			error("For form XII, letters 3 and 5 of headword " .. headword ..
				" should be the same")
		end
		check(4, waw)
		radstart = 5
	elseif form == "XIII" then
		check_len(5, 5)
		check(1, alif)
		rad1 = letters[2]
		rad2 = letters[3]
		check(4, waw)
		rad3 = letters[5]
		if rad3 == amaq then
			weakness = "final-weak"
		else
			weakness = "sound"
		end
	elseif form == "XIV" then
		check_len(6, 6)
		check(1, alif)
		rad1 = letters[2]
		rad2 = letters[3]
		check(4, nuun)
		rad3 = letters[5]
		if letters[6] == amaq then
			check_waw_yaa(rad3)
			weakness = "final-weak"
		else
			if letters[5] ~= letters[6] then
				error("For form XIV, letters 5 and 6 of headword " .. headword ..
					" should be the same")
			end
			weakness = "sound"
		end
	elseif form == "XV" then
		check_len(6, 6)
		check(1, alif)
		rad1 = letters[2]
		rad2 = letters[3]
		check(4, nuun)
		rad3 = letters[5]
		if rad3 == yaa then
			check(6, alif)
		else
			check(6, amaq)
		end
		weakness = "sound"
	else
		error("Don't recognize form " .. form)
	end

	-- Process the last two radicals. RADSTART is the index of the
	-- first of the two. If it's nil then all radicals have already been
	-- processed above, and we don't do anything.
	if radstart ~= nil then
		-- there must be one or two letters left
		check_len(radstart, radstart + 1)
		if len == radstart then
			-- if one letter left, then it's a geminate verb
			if form_supports_geminate(form) then
				weakness = "geminate"
				rad2 = letters[len]
				rad3 = letters[len]
			else
				-- oops, geminate verbs not allowed in this form; signal
				-- an error
				check_len(radstart + 1, radstart + 1)
			end
		elseif quadlit then
			-- process last two radicals of a quadriliteral form
			rad3 = letters[radstart]
			rad4 = letters[radstart + 1]
			if rad4 == amaq or rad4 == alif and rad3 == yaa then
				if form_supports_final_weak(form) then
					weakness = "final-weak"
					-- ambiguous radical; randomly pick waw as radical (but avoid
					-- two waws in a row); it could be waw or yaa, but doesn't
					-- affect the conjugation
					rad4 = rad3 == waw and "y" or "w"
				else
					error("For headword " .. headword ..
						", last radical is " .. rad4 .. " but form " .. form ..
						" doesn't support final-weak verbs")
				end
			else
				weakness = "sound"
			end
		else
			-- process last two radicals of a triliteral form
			rad2 = letters[radstart]
			rad3 = letters[radstart + 1]
			if form == "I" and (is_waw_yaa(rad3) or rad3 == alif or rad3 == amaq) then
				-- check for final-weak form I verb. It can end in tall alif
				-- (rad3 = waw) or alif maqṣūra (rad3 = yaa) or a waw or yaa
				-- (with a past vowel of i or u, e.g. nasiya/yansā "forget").
				if rad1 == waw then
					weakness = "assimilated+final-weak"
				else
					weakness = "final-weak"
				end
				if rad3 == alif then
					rad3 = waw
				elseif rad3 == amaq then
					rad3 = yaa
				end
			elseif rad3 == amaq or rad2 == yaa and rad3 == alif then
				if form_supports_final_weak(form) then
					weakness = "final-weak"
				else
					error("For headword " .. headword ..
						", last radical is " .. rad3 .. " but form " .. form ..
						" doesn't support final-weak verbs")
				end
				-- ambiguous radical; randomly pick waw as radical (but avoid
				-- two waws in a row); it could be waw or yaa, but doesn't
				-- affect the conjugation
				rad3 = rad2 == waw and "y" or "w"
			elseif rad2 == alif then
				if form_supports_hollow(form) then
					weakness = "hollow"
					-- ambiguous radical; could be waw or yaa; if form I,
					-- it's critical to get this right, and the caller checks
					-- for this situation, attempts to infer radical from
					-- non-past vowel, and if that fails, signals an error
					rad2 = "w"
				else
					error("For headword " .. headword ..
						", second radical is alif but form " .. form ..
						" doesn't support hollow verbs")
				end
			elseif form == "I" and rad1 == waw then
				weakness = "assimilated"
			else
				weakness = "sound"
			end
		end
	end

	-- convert radicals to canonical form (handle various hamza varieties and
	-- check for misplaced alif or alif maqṣūra; legitimate cases of these
	-- letters are handled above)
	local function convert(rad, index)
		if rad == hamza_on_alif or rad == hamza_under_alif or
			rad == hamza_on_waw or rad == hamza_on_yaa then
			return hamza
		elseif rad == amaq then
			error("For form " .. form .. ", headword " .. headword ..
				", radical " .. index .. " must not be alif maqṣūra")
		elseif rad == alif then
			error("For form " .. form .. ", headword " .. headword ..
				", radical " .. index .. " must not be alif")
		else
			return rad
		end
	end
	rad1 = convert(rad1, 1)
	rad2 = convert(rad2, 2)
	rad3 = convert(rad3, 3)
	rad4 = convert(rad4, 4)
	
	return weakness, rad1, rad2, rad3, rad4
end

-- given form, weakness and radicals, check to make sure the radicals present
-- are allowable for the weakness. Hamzas on alif/waw/yaa seats are never
-- allowed (should always appear as hamza-on-the-line), and various weaknesses
-- have various strictures on allowable consonants.
function check_radicals(form, weakness, rad1, rad2, rad3, rad4)
	local function hamza_check(index, rad)
		if rad == hamza_on_alif or rad == hamza_under_alif or
			rad == hamza_on_waw or rad == hamza_on_yaa then
			error("Radical " .. index .. " is " .. rad .. " but should be ء (hamza on the line)")
		end
	end
	local function check_waw_yaa(index, rad)
		if rad ~= waw and rad ~= yaa then
			error("Radical " .. index .. " is " .. rad .. " but should be و or ي")
		end
	end
	local function check_not_waw_yaa(index, rad)
		if rad == waw or rad == yaa then
			error("In a sound verb, radical " .. index .. " should not be و or ي")
		end
	end
	hamza_check(rad1)
	hamza_check(rad2)
	hamza_check(rad3)
	hamza_check(rad4)
	if weakness == "assimilated" or weakness == "assimilated+final-weak" then
		if rad1 ~= waw then
			error("Radical 1 is " .. rad1 .. " but should be و")
		end
	-- don't check that non-assimilated form I verbs don't have waw as their
	-- first radical because some form-I verbs exist where a first-radical waw
	-- behaves as sound, e.g. wajuha yawjuhu "to be distinguished".
	end
	if weakness == "final-weak" or weakness == "assimilated+final-weak" then
		if rad4 then
			check_waw_yaa(4, rad4)
		else
			check_waw_yaa(3, rad3)
		end
	elseif form_supports_final_weak(form) then
		-- non-final-weak verbs cannot have weak final radical if there's a corresponding
		-- final-weak verb category. I think this is safe. We may have problems with
		-- ḥayya/ḥayiya yaḥyā if we treat it as a geminate verb.
		if rad4 then
			check_not_waw_yaa(4, rad4)
		else
			check_not_waw_yaa(3, rad3)
		end
	end
	if weakness == "hollow" then
		check_waw_yaa(2, rad2)
	-- don't check that non-hollow verbs in forms that support hollow verbs
	-- don't have waw or yaa as their second radical because some verbs exist
	-- where a middle-radical waw/yaa behaves as sound, e.g. form-VIII izdawaja
	-- "to be in pairs".
	end
	if weakness == "geminate" then
		if rad4 then
			error("Internal error. No geminate quadrilaterals, should not be seen.")
		end
		if rad2 ~= rad3 then
			error("Weakness is geminate; radical 3 is " .. rad3 .. " but should be same as radical 2 " .. rad2 .. ".")
		end
	elseif form_supports_geminate(form) then
		-- non-geminate verbs cannot have second and third radical same if there's
		-- a corresponding geminate verb category. I think this is safe. We
		-- don't fuss over double waw or double yaa because this could legitimately
		-- be a final-weak verb with middle waw/yaa, treated as sound.
		if rad4 then
			error("Internal error. No quadrilaterals should support geminate verbs.")
		end
		if rad2 == rad3 and not is_waw_yaa(rad2) then
			error("Weakness is '" .. weakness .. "'; radical 2 and 3 are same at " .. rad2 .. " but should not be; consider making weakness 'geminate'")
		end
	end
end

function initialize_categories(categories, headword_categories, form, weakness, rad1, rad2, rad3, rad4)
	-- We have to distinguish weakness by form and weakness by conjugation.
	-- Weakness by form merely indicates the presence of weak letters in
	-- certain positions in the radicals. Weakness by conjugation is related
	-- to how the verbs are conjugated. For example, form-II verbs that are
	-- "hollow by form" (middle radical is waw or yaa) are conjugated as sound
	-- verbs. Another example: form-I verbs with initial waw are "assimilated
	-- by form" and most are assimilated by conjugation as well, but a few
	-- are sound by conjugation, e.g. wajuha yawjuhu "to be distinguished"
	-- (rather than wajuha yajuhu); similarly for some hollow-by-form verbs
	-- in various forms, e.g. form VIII izdawaja yazdawiju "to be in pairs"
	-- (rather than izdāja yazdāju). When most references say just plain
	-- "hollow" or "assimilated" or whatever verbs, they mean by form, so
	-- we name the categories appropriately, where e.g. "Arabic hollow verbs"
	-- means by form, "Arabic hollow verbs by conjugation" means by
	-- conjugation.
	table.insert(categories, "Arabic form-" .. form .. " verbs")
	table.insert(headword_categories, "Arabic form-" .. form .. " verbs")
	table.insert(categories, "Arabic " .. weakness .. " verbs by conjugation")
	table.insert(headword_categories, "Arabic " .. weakness .. " verbs by conjugation")
	local formweak = {}
	if is_waw_yaa(rad1) then
		table.insert(formweak, "assimilated")
	end
	if is_waw_yaa(rad2) and rad4 == nil then
		table.insert(formweak, "hollow")
	end
	if is_waw_yaa(rad4) or rad4 == nil and is_waw_yaa(rad3) then
		table.insert(formweak, "final-weak")
	end
	if rad4 == nil and rad2 == rad3 then
		table.insert(formweak, "geminate")
	end
	if rad1 == hamza or rad2 == hamza or rad3 == hamza or rad4 == hamza then
		table.insert(formweak, "hamzated")
	end
	if not is_waw_yaa(rad1) and not is_waw_yaa(rad2) and not is_waw_yaa(rad3) and
			not is_waw_yaa(rad4) and rad1 ~= hamza and rad2 ~= hamza and
			rad3 ~= hamza and rad4 ~= hamza then
		table.insert(formweak, "sound")
	end
	for _, fw in ipairs(formweak) do
		table.insert(categories, "Arabic " .. fw .. " form-" .. form .. " verbs")
		table.insert(categories, "Arabic " .. fw .. " verbs")
		table.insert(headword_categories, "Arabic " .. fw .. " form-" .. form .. " verbs")
		table.insert(headword_categories, "Arabic " .. fw .. " verbs")
	end
	return formweak
end

-------------------------------------------------------
-- Conjugation functions for specific conjugation types
-------------------------------------------------------

-- Check that the past or non-past vowel is a, i, or u. VOWEL is the vowel to
-- check and VTYPE indicates whether it's past or non-past and is used in
-- the error message.
function check_aiu(vtype, vowel)
	if vowel ~= "a" and vowel ~= "i" and vowel ~= "u" then
		error(vtype .. " vowel '" .. vowel .. "' should be a, i, or u")
	end
end

-- Is radical waw (و) or yaa (ي)?
function is_waw_yaa(rad)
	return rad == waw or rad == yaa
end

-- Check that radical is waw (و) or yaa (ي), error if not
function check_waw_yaa(rad)
	if not is_waw_yaa(rad) then
		error("Expecting weak radical: '" .. rad .. "' should be " .. waw .. " or " .. yaa)
	end
end

-- Is radical guttural? This favors a non-past vowel of "a"
function is_guttural(rad)
	return rad == hamza or rad == "ه" or rad == "ع" or rad == "ح"
end

-- Derive default non-past vowel from past vowel. Most common possibilities are
-- a/u, a/i, a/a if rad2 or rad3 are guttural, i/a, u/u. We choose a/u over a/i.
function nonpast_from_past_vowel(past_vowel, rad2, rad3)
	return past_vowel == "i" and "a" or past_vowel == "u" and "u" or
		(is_guttural(rad2) or is_guttural(rad3)) and "a" or "u"
end

-- determine the imperative vowel based on non-past vowel
function imper_vowel_from_nonpast(nonpast_vowel)
	if nonpast_vowel == "a" or nonpast_vowel == "i" then
		return "i"
	elseif nonpast_vowel == "u" then
		return "u"
	else
		error("Non-past vowel '" .. nonpast_vowel .. "' isn't a, i, or u, should have been caught earlier")
	end
end

-- Convert short vowel to equivalent long vowel (a -> alif, u -> waw, i -> yaa).
function short_to_long_vowel(vowel)
	if vowel == dia.a then return alif
	elseif vowel == dia.i then return yaa
	elseif vowel == dia.u then return waw
	else
		error("Vowel '" .. vowel .. "' isn't a, i, or u, should have been caught earlier")
	end
end

-- Implement form-I sound or assimilated verb. ASSIMILATED is true for
-- assimilated verbs.
local function make_form_i_sound_assimilated_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, assimilated)
	-- need to provide two vowels - past and non-past
	past_vowel = past_vowel or "a"
	nonpast_vowel = nonpast_vowel or nonpast_from_past_vowel(past_vowel, rad2, rad3)
	check_aiu("past", past_vowel)
	check_aiu("non-past", nonpast_vowel)

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- past and non-past stems, active and passive 
	local past_stem = rad1 .. dia.a .. rad2 .. dia[past_vowel] .. rad3
	local nonpast_stem = assimilated and rad2 .. dia[nonpast_vowel] .. rad3 or
		rad1 .. dia.s .. rad2 .. dia[nonpast_vowel] .. rad3
	local ps_past_stem = rad1 .. dia.u .. rad2 .. dia.i .. rad3
	local ps_nonpast_stem = rad1 .. dia.s .. rad2 .. dia.a .. rad3

	-- determine the imperative vowel based on non-past vowel
	local imper_vowel = imper_vowel_from_nonpast(nonpast_vowel)
	
	-- imperative stem
	-- check for irregular verb with reduced imperative (أَخَذَ or أَكَلَ or أَمَرَ)
	local reducedimp = reduced_imperative_verb(rad1, rad2, rad3)
	if reducedimp then
		data.irregular = true
	end
	local imper_stem_suffix = rad2 .. dia[nonpast_vowel] .. rad3
	local imper_stem_base = (assimilated or reducedimp) and "" or
		alif .. dia[imper_vowel] ..
		(rad1 == hamza and short_to_long_vowel(dia[imper_vowel]) or rad1 .. dia.s)
	local imper_stem = imper_stem_base .. imper_stem_suffix

	-- make forms
	make_sound_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, "a")

	-- Check for irregular verb سَأَلَ with alternative jussive and imperative.
	-- Calling this after make_sound_verb() adds additional entries to the
	-- paradigm forms.
	if saal_radicals(rad1, rad2, rad3) then
		data.irregular = true
		nonpast_1stem_conj(data, "juss", "a", "سَل")
		nonpast_1stem_conj(data, "ps-juss", "u", "سَل")
		make_1stem_imperative(data, "سَل")
	end

	-- active participle
	insert_form(data, "ap", rad1 .. aa .. rad2 .. dia.i .. rad3 .. dia.un)
	-- passive participle
	insert_form(data, "pp", ma .. rad1 .. dia.s .. rad2 .. dia.u .. "و" .. rad3 .. dia.un)
end
	
conjugations["I-sound"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_sound_assimilated_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, false)
end

conjugations["I-assimilated"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_sound_assimilated_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, "assimilated")
end

-- Implement form-I final-weak assimilated+final-weak verb. ASSIMILATED is true
-- for assimilated verbs.
local function make_form_i_final_weak_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, assimilated)
	-- need to provide two vowels - past and non-past
	local past_vowel = past_vowel or "a"
	local nonpast_vowel = nonpast_vowel or past_vowel == "i" and "a" or
		past_vowel == "u" and "u" or rad3 == yaa and "i" or "u"
	check_aiu("past", past_vowel)
	check_aiu("non-past", nonpast_vowel)

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- past and non-past stems, active and passive, and imperative stem
	local past_stem = rad1 .. dia.a .. rad2
	local ps_past_stem = rad1 .. dia.u .. rad2
	local nonpast_stem, ps_nonpast_stem, imper_stem
	if raa_radicals(rad1, rad2, rad3) then
		data.irregular = true
		nonpast_stem = rad1
		ps_nonpast_stem = rad1
		imper_stem = rad1
	else
		ps_nonpast_stem = rad1 .. dia.s .. rad2
		if assimilated then
			nonpast_stem = rad2
			imper_stem = rad2
		else
			nonpast_stem = ps_nonpast_stem
			-- determine the imperative vowel based on non-past vowel
			local imper_vowel = imper_vowel_from_nonpast(nonpast_vowel)
			imper_stem =  alif .. dia[imper_vowel] ..
				(rad1 == hamza and short_to_long_vowel(dia[imper_vowel])
					or rad1 .. dia.s) ..
				rad2
		end
	end

	-- make forms
	make_form_i_final_weak_verb_from_stems(data, past_stem, ps_past_stem,
		nonpast_stem, ps_nonpast_stem, imper_stem, rad3, past_vowel,
		nonpast_vowel)

	-- active participle
	insert_form(data, "ap", rad1 .. aa .. rad2 .. dia.in_)
	-- passive participle
	insert_form(data, "pp", ma .. rad1 .. dia.s .. rad2 ..
		(rad3 == yaa and ii or uu) .. dia.sh .. dia.un)
end
	
conjugations["I-final-weak"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_final_weak_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, false)
end

conjugations["I-assimilated+final-weak"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_final_weak_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, "assimilated")
end

conjugations["I-hollow"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	-- need to specify up to two vowels, past and non-past
	local past_vowel = past_vowel or rad2 == yaa and "i" or "u"
	local nonpast_vowel = nonpast_vowel or past_vowel
	check_aiu("past", past_vowel)
	check_aiu("non-past", nonpast_vowel)
	if past_vowel == "a" then
		error("For form I hollow, past vowel cannot be 'a'")
	end
	local lengthened_nonpast = nonpast_vowel == "u" and uu or
		nonpast_vowel == "i" and ii or aa

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- active past stems - vowel (v) and consonant (c)
	local past_v_stem = rad1 .. aa .. rad3
	local past_c_stem = rad1 .. dia[past_vowel] .. rad3

	-- active non-past stems - vowel (v) and consonant (c)
	local nonpast_v_stem = rad1 .. lengthened_nonpast .. rad3
	local nonpast_c_stem = rad1 .. dia[nonpast_vowel] .. rad3

	-- passive past stems - vowel (v) and consonant (c)
	-- 'ufīla, 'ufiltu
	local ps_past_v_stem = rad1 .. ii .. rad3
	local ps_past_c_stem = rad1 .. dia.i .. rad3

	-- passive non-past stems - vowel (v) and consonant (c)
	-- yufāla/yufalna
	-- stem is built differently but conjugation is identical to sound verbs
	local ps_nonpast_v_stem = rad1 .. aa .. rad3
	local ps_nonpast_c_stem = rad1 .. dia.a .. rad3

	-- imperative stem
	local imper_v_stem = nonpast_v_stem
	local imper_c_stem = nonpast_c_stem

	-- make forms
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, "a", false)
	
	-- active participle
	insert_form(data, "ap", rad3 == hamza and rad1 .. aa .. hamza .. dia.in_ or
		rad1 .. aa .. hamza .. dia.i .. rad3 .. dia.un)
	-- passive participle
	insert_form(data, "pp", ma .. rad1 .. (rad2 == yaa and ii or uu) .. rad3 .. dia.un)
end

conjugations["I-geminate"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	-- need to specify two vowels, past and non-past
	local past_vowel = past_vowel or "a"
	local nonpast_vowel = nonpast_vowel or nonpast_from_past_vowel(past_vowel, rad2, rad3)

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- active past stems - vowel (v) and consonant (c)
	local past_v_stem = rad1 .. dia.a .. rad2 .. dia.sh
	local past_c_stem = rad1 .. dia.a .. rad2 .. dia[past_vowel] .. rad2

	-- active non-past stems - vowel (v) and consonant (c)
	local nonpast_v_stem = rad1 .. dia[nonpast_vowel] .. rad2 .. dia.sh
	local nonpast_c_stem = rad1 .. dia.s .. rad2 .. dia[nonpast_vowel] .. rad2

	-- passive past stems - vowel (v) and consonant (c)
	-- dulla/dulilta
	local ps_past_v_stem = rad1 .. dia.u .. rad2 .. dia.sh
	local ps_past_c_stem = rad1 .. dia.u .. rad2 .. dia.i .. rad2

	-- passive non-past stems - vowel (v) and consonant (c)
	--yudallu/yudlalna
	-- stem is built differently but conjugation is identical to sound verbs
	local ps_nonpast_v_stem = rad1 .. dia.a .. rad2 .. dia.sh
	local ps_nonpast_c_stem = rad1 .. dia.s .. rad2 .. dia.a .. rad2

	-- determine the imperative vowel based on non-past vowel
	local imper_vowel = imper_vowel_from_nonpast(nonpast_vowel)

	-- imperative stem
	local imper_v_stem = rad1 .. dia[nonpast_vowel] .. rad2 .. dia.sh
	local imper_c_stem = alif .. dia[imper_vowel] ..
		(rad1 == hamza and short_to_long_vowel(dia[imper_vowel]) or rad1 .. dia.s) ..
		rad2 .. dia[nonpast_vowel] .. rad2

	-- make forms
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, "a", "geminate")
	
	-- active participle
	insert_form(data, "ap", rad1 .. aa .. rad2 .. dia.sh .. dia.un)
	-- passive participle
	insert_form(data, "pp", ma .. rad1 .. dia.s .. rad2 .. dia.u .. "و" .. rad2 .. dia.un)
end

-- Make form II or V sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil, and FORM distinguishes II from V.
function make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, rad3, form)
	local final_weak = rad3 == nil
	local vn = form == "V" and
		"تَ" .. rad1 .. dia.a .. rad2 .. dia.sh ..
			(final_weak and dia.in_ or dia.u .. rad3 .. dia.un) or
		"تَ" .. rad1 .. dia.s .. rad2 .. dia.i .. "ي" ..
			(final_weak and ah or rad3) .. dia.un
	local ta_pref = form == "V" and "تَ" or ""
	local tu_pref = form == "V" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. dia.a .. rad2 .. dia.sh
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. dia.u .. rad2 .. dia.sh

	-- make forms
	make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

conjugations["II-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, rad3, "II")
end

conjugations["II-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, nil, "II")
end

-- Make form III or VI sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil, and FORM distinguishes III from VI.
function make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad3, form)
	local final_weak = rad3 == nil
	local vn = form == "VI" and
		"تَ" .. rad1 .. aa .. rad2 ..
			(final_weak and dia.in_ or dia.u .. rad3 .. dia.un) or
		{mu .. rad1 .. aa .. rad2 .. (final_weak and aah or dia.a .. rad3 .. ah) .. dia.un,
			rad1 .. dia.i .. rad2 .. aa .. (final_weak and hamza or rad3) .. dia.un}
	local ta_pref = form == "VI" and "تَ" or ""
	local tu_pref = form == "VI" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. aa .. rad2
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. uu .. rad2

	-- make forms
	make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

conjugations["III-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad3, "III")
end

conjugations["III-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, nil, "III")
end

-- Make form III or VI geminate verb. FORM distinguishes III from VI.
function make_form_iii_vi_geminate_verb(data, args, rad1, rad2, form)
	-- alternative verbal noun فِعَالٌ will be inserted when we add sound forms below
	local vn = form == "VI" and
		{"تَ" .. rad1 .. aa .. rad2 .. dia.sh .. dia.un} or
		{mu .. rad1 .. aa .. rad2 .. dia.sh .. ah .. dia.un}
	local ta_pref = form == "VI" and "تَ" or ""
	local tu_pref = form == "VI" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. aa
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. uu

	-- make forms
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
	
	-- Also add alternative sound (non-compressed) forms. This will lead to
	-- some duplicate entries, but they are removed in get_spans().
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad2, form)
end

conjugations["III-geminate"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_geminate_verb(data, args, rad1, rad2, "III")
end

-- Make form IV sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
function make_form_iv_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	local final_weak = rad3 == nil

	-- core of stem base, minus stem prefixes
	local stem_core
	
	-- check for irregular verb أَرَى
	if raa_radicals(rad1, rad2, final_weak and yaa or rad3) then
		data.irregular = true
		stem_core = rad1
	else
		stem_core =	rad1 .. dia.s .. rad2
	end

	-- verbal noun
	local vn = hamza .. dia.i .. stem_core .. aa ..
		(final_weak and hamza or rad3) .. dia.un

	-- various stem bases
	local past_stem_base = hamza .. dia.a .. stem_core
	local nonpast_stem_base = stem_core
	local ps_past_stem_base = hamza .. dia.u .. stem_core

	-- make forms
	make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IV")
end

conjugations["IV-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_iv_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["IV-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_iv_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["IV-hollow"] = function(data, args, rad1, rad2, rad3)
	-- verbal noun
	local vn = hamza .. dia.i .. rad1 .. aa .. rad3 .. ah .. dia.un

	-- various stem bases
	local past_stem_base = hamza .. dia.a .. rad1
	local nonpast_stem_base = rad1
	local ps_past_stem_base = hamza .. dia.u .. rad1

	-- make forms
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IV")
end

conjugations["IV-geminate"] = function(data, args, rad1, rad2, rad3)
	local vn = hamza .. dia.i .. rad1 .. dia.s .. rad2 .. aa .. rad2 .. dia.un

	-- various stem bases
	local past_stem_base = hamza .. dia.a .. rad1
	local nonpast_stem_base = rad1
	local ps_past_stem_base = hamza .. dia.u .. rad1

	-- make forms
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IV")
end

conjugations["V-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, rad3, "V")
end

conjugations["V-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, nil, "V")
end

conjugations["VI-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad3, "VI")
end

conjugations["VI-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, nil, "VI")
end

conjugations["VI-geminate"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_geminate_verb(data, args, rad1, rad2, "VI")
end

-- Make a verbal noun of the general form that applies to forms VII and above.
-- RAD12 is the first consonant cluster (after initial اِ) and RAD34 is the
-- second consonant cluster. RAD5 is the final consonant, or nil for final-weak
-- verbs.
function high_form_verbal_noun(rad12, rad34, rad5)
	return "اِ" .. rad12 .. dia.i .. rad34 .. aa ..
		(rad5 == nil and hamza or rad5) .. dia.un
end

-- Populate a sound or final-weak verb for any of the various high-numbered
-- augmented forms (form VII and up) that have up to 5 consonants in two
-- clusters in the stem and the same pattern of vowels between.
-- Some of these consonants in certain forms are w's, which leads to apparent
-- anomalies in certain stems of these forms, but these anomalies are handled
-- automatically in postprocessing, where we resolve sequences of iwC -> īC,
-- uwC -> ūC, w + sukūn + w -> w + shadda. 
--
-- RAD12 is the first consonant cluster (after initial اِ) and RAD34 is the
-- second consonant cluster. RAD5 is the final consonant, or nil for final-weak
-- verbs.
function make_high_form_sound_final_weak_verb(data, args, rad12, rad34, rad5, form)
	local final_weak = rad5 == nil
	local vn = high_form_verbal_noun(rad12, rad34, rad5)

	-- various stem bases
	local nonpast_stem_base = rad12 .. dia.a .. rad34
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. rad12 .. dia.u .. rad34

	-- make forms
	make_augmented_sound_final_weak_verb(data, args, rad5,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

-- Make form VII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
function make_form_vii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high_form_sound_final_weak_verb(data, args, "نْ" .. rad1, rad2, rad3, "VII")
end

conjugations["VII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_vii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["VII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_vii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["VII-hollow"] = function(data, args, rad1, rad2, rad3)
	local nrad1 = "نْ" .. rad1
	local vn = high_form_verbal_noun(nrad1, yaa, rad3)

	-- various stem bases
	local nonpast_stem_base = nrad1
	local past_stem_base = "اِ" ..nonpast_stem_base
	local ps_past_stem_base = "اُ" .. nrad1

	-- make forms
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VII")
end

conjugations["VII-geminate"] = function(data, args, rad1, rad2, rad3)
	local nrad1 = "نْ" .. rad1
	local vn = high_form_verbal_noun(nrad1, rad2, rad2)

	-- various stem bases
	local nonpast_stem_base = nrad1 .. dia.a
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. nrad1 .. dia.u

	-- make forms
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VII")
end

-- Join the infixed tā' (ت) to the first radical in form VIII verbs. This may
-- cause assimilation of the tā' to the radical or in some cases the radical to
-- the tā'.
function join_taa(rad)
	if rad == waw or rad == yaa or rad == "ت" then return "تّ"
	elseif rad == "د" then return "دّ"
	elseif rad == "ث" then return "ثّ"
	elseif rad == "ذ" then return "ذّ"
	elseif rad == "ز" then return "زْد"
	elseif rad == "ص" then return "صْط"
	elseif rad == "ض" then return "ضْط"
	elseif rad == "ط" then return "طّ"
	elseif rad == "ظ" then return "ظّ"
	else return rad .. dia.s .. "ت"
	end
end

-- Return Form VIII verbal noun. RAD3 is nil for final-weak verbs. If RAD1 is
-- hamza, there are two alternatives.
function form_viii_verbal_noun(rad1, rad2, rad3)
	local vn = high_form_verbal_noun(join_taa(rad1), rad2, rad3)
	if rad1 == hamza then
		return {vn, high_form_verbal_noun(yaa .. taa, rad2, rad3)}
	else
		return {vn}
	end
end

-- Make form VIII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
function make_form_viii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	-- check for irregular verb اِتَّخَذَ
	if axadh_radicals(rad1, rad2, rad3) then
		data.irregular = true
		rad1 = taa
	end
	make_high_form_sound_final_weak_verb(data, args, join_taa(rad1), rad2, rad3,
		"VIII")

	-- Add alternative forms if verb is first-hamza. Any duplicates are
	-- removed in get_spans().
	if rad1 == hamza then
		local vn = form_viii_verbal_noun(rad1, rad2, rad3)
		local past_stem_base2 = "اِيتَ" .. rad2
		local nonpast_stem_base2 = join_taa(rad1) .. dia.a .. rad2
		local ps_past_stem_base2 = "اُوتُ" .. rad2
		make_augmented_sound_final_weak_verb(data, args, rad3,
			past_stem_base2, nonpast_stem_base2, ps_past_stem_base2, vn, "VIII")
	end
end

conjugations["VIII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_viii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["VIII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_viii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["VIII-hollow"] = function(data, args, rad1, rad2, rad3)
	local vn = form_viii_verbal_noun(rad1, yaa, rad3)

	-- various stem bases
	local nonpast_stem_base = join_taa(rad1)
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. nonpast_stem_base

	-- make forms
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VIII")

	-- Add alternative forms if verb is first-hamza. Any duplicates are
	-- removed in get_spans().
	if rad1 == hamza then
		local past_stem_base2 = "اِيت"
		local nonpast_stem_base2 = nonpast_stem_base
		local ps_past_stem_base2 = "اُوت"
		make_augmented_hollow_verb(data, args, rad3,
			past_stem_base2, nonpast_stem_base2, ps_past_stem_base2, vn, "VIII")
	end
end

conjugations["VIII-geminate"] = function(data, args, rad1, rad2, rad3)
	local vn = form_viii_verbal_noun(rad1, rad2, rad2)

	-- various stem bases
	local nonpast_stem_base = join_taa(rad1) .. dia.a
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. join_taa(rad1) .. dia.u

	-- make forms
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VIII")

	-- Add alternative forms if verb is first-hamza. Any duplicates are
	-- removed in get_spans().
	if rad1 == hamza then
		local past_stem_base2 = "اِيتَ"
		local nonpast_stem_base2 = nonpast_stem_base
		local ps_past_stem_base2 = "اُوتُ"
		make_augmented_geminate_verb(data, args, rad2,
			past_stem_base2, nonpast_stem_base2, ps_past_stem_base2, vn, "VIII")
	end
end

conjugations["IX-sound"] = function(data, args, rad1, rad2, rad3)
	local ipref = "اِ"
	local vn = ipref .. rad1 .. dia.s .. rad2 .. dia.i .. rad3 .. aa .. rad3 .. dia.un

	-- various stem bases
	local nonpast_stem_base = rad1 .. dia.s .. rad2 .. dia.a
	local past_stem_base = ipref .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. rad1 .. dia.s .. rad2 .. dia.u

	-- make forms
	make_augmented_geminate_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IX")
end

conjugations["IX-final-weak"] = function(data, args, rad1, rad2, rad3)
	error("FIXME: Not yet implemented")
end

-- Populate a sound or final-weak verb for any of the various high-numbered
-- augmented forms that have 5 consonants in the stem and the same pattern of
-- vowels. Some of these consonants in certain forms are w's, which leads to
-- apparent anomalies in certain stems of these forms, but these anomalies
-- are handled automatically in postprocessing, where we resolve sequences of
-- iwC -> īC, uwC -> ūC, w + sukūn + w -> w + shadda. 
function make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, rad5, form)
	make_high_form_sound_final_weak_verb(data, args, rad1 .. dia.s .. rad2,
		rad3 .. dia.s .. rad4, rad5, form)
end

-- Make form X sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
function make_form_x_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high5_form_sound_final_weak_verb(data, args, siin, taa, rad1, rad2, rad3, "X")
	-- check for irregular verb اِسْتَحْيَا (also اِسْتَحَى or اِسْتَحَّى)
	if hayy_radicals(rad1, rad2, rad3 or yaa) then
		data.irregular = true
		-- Add alternative entries to the verbal paradigms. Any duplicates are
		-- removed in get_spans().
		make_high_form_sound_final_weak_verb(data, args, siin .. taa, rad1, rad3, "X")
		make_high_form_sound_final_weak_verb(data, args, siin .. taa, rad1 .. dia.sh, rad3, "X")
	end
end

conjugations["X-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_x_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["X-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_x_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["X-hollow"] = function(data, args, rad1, rad2, rad3)
	local vn = "اِسْتِ" .. rad1 .. aa .. rad3 .. ah .. dia.un

	-- various stem bases
	local past_stem_base = "اِسْتَ" .. rad1
	local nonpast_stem_base = "سْتَ" .. rad1
	local ps_past_stem_base = "اُسْتُ" .. rad1

	-- make forms
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "X")
end

conjugations["X-geminate"] = function(data, args, rad1, rad2, rad3)
	local vn = "اِسْتِ" .. rad1 .. dia.s .. rad2 .. aa .. rad2 .. dia.un

	-- various stem bases
	local past_stem_base = "اِسْتَ" .. rad1
	local nonpast_stem_base = "سْتَ" .. rad1
	local ps_past_stem_base = "اُسْتُ" .. rad1

	-- make forms
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "X")
end

conjugations["XI-sound"] = function(data, args, rad1, rad2, rad3)
	local ipref = "اِ"
	local vn = ipref .. rad1 .. dia.s .. rad2 .. ii .. rad3 .. aa .. rad3 .. dia.un

	-- various stem bases
	local nonpast_stem_base = rad1 .. dia.s .. rad2 .. aa
	local past_stem_base = ipref .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. rad1 .. dia.s .. rad2 .. uu

	-- make forms
	make_augmented_geminate_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "XI")
end

-- probably no form XI final-weak, since already geminate in form; would behave as XI-sound

-- Make form XII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
function make_form_xii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, waw, rad2, rad3, "XII")
end

conjugations["XII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["XII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_xii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

-- Make form XIII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
function make_form_xiii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, waw, waw, rad3, "XIII")
end

conjugations["XIII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xiii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["XIII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_xiii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

-- Make a form XIV or XV sound or final-weak verb. Last radical appears twice
-- (if`anlala / yaf`anlilu) so if it were w or y you'd get if`anwā / yaf`anwī
-- or if`anyā / yaf`anyī, i.e. we need the identity of the radical, so the
-- normal trick of passing nil as rad3 into these types of functions won't work.
-- Instead we pass the full radical as well as a flag indicating whether the
-- verb is final-weak. The last radical need not be w or y; in fact this is
-- exactly what form XV is about.
function make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, final_weak, form)
	local lastrad = not final_weak and rad3 or nil
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, nuun, rad3, lastrad, form)
end

conjugations["XIV-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, false, "XIV")
end

conjugations["XIV-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, true, "XIV")
end

conjugations["XV-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, true, "XV")
end

-- probably no form XV final-weak, since already final-weak in form; would behave as XV-sound

-- Make form Iq or IIq sound or final-weak verb. Final-weak verbs are identified
-- by RAD4 = nil. FORM distinguishes Iq from IIq.
function make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, form)
	local final_weak = rad4 == nil
	local vn = form == "IIq" and
		"تَ" .. rad1 .. dia.a .. rad2 .. dia.s .. rad3 ..
			(final_weak and dia.in_ or dia.u .. rad4 .. dia.un) or
		rad1 .. dia.a .. rad2 .. dia.s .. rad3 ..
			(final_weak and aah or dia.a .. rad4 .. ah) .. dia.un
	local ta_pref = form == "IIq" and "تَ" or ""
	local tu_pref = form == "IIq" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. dia.a .. rad2 .. dia.s .. rad3
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. dia.u .. rad2 .. dia.s .. rad3

	-- make forms
	make_augmented_sound_final_weak_verb(data, args, rad4,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

conjugations["Iq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, "Iq")
end

conjugations["Iq-final-weak"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, nil, "Iq")
end

conjugations["IIq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, "IIq")
end

conjugations["IIq-final-weak"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, nil, "IIq")
end

-- Make form IIIq sound or final-weak verb. Final-weak verbs are identified
-- by RAD4 = nil.
function make_form_iiiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4)
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, nuun, rad3, rad4, "IIIq")
end

conjugations["IIIq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iiiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4)
end

conjugations["IIIq-final-weak"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iiiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, nil)
end

conjugations["IVq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	local ipref = "اِ"
	local vn = ipref .. rad1 .. dia.s .. rad2 .. dia.i .. rad3 .. dia.s .. rad4 .. aa .. rad4 .. dia.un

	-- various stem bases
	local past_stem_base = ipref .. rad1 .. dia.s .. rad2 .. dia.a .. rad3
	local nonpast_stem_base = rad1 .. dia.s .. rad2 .. dia.a .. rad3
	local ps_past_stem_base = "اُ" .. rad1 .. dia.s .. rad2 .. dia.u .. rad3

	-- make forms
	make_augmented_geminate_verb(data, args, rad4,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IVq")
end

-- probably no form IVq final-weak, since already geminate in form; would behave as IVq-sound

-- Inflection functions

-- Implementation of inflect_tense(). See that function. Also used directly
-- to add the imperative, which has only five forms.
function inflect_tense_1(data, tense, prefixes, stems, endings, pnums)
	if prefixes == nil then
		error("For tense '" .. tense .. "', prefixes = nil")
	end
	if stems == nil then
		error("For tense '" .. tense .. "', stems = nil")
	end
	if endings == nil then
		error("For tense '" .. tense .. "', endings = nil")
	end
	if type(prefixes) == "table" and #pnums ~= #prefixes then
		error("For tense '" .. tense .. "', found " .. #prefixes .. " prefixes but expected " .. #pnums)
	end
	if type(stems) == "table" and #pnums ~= #stems then
		error("For tense '" .. tense .. "', found " .. #stems .. " stems but expected " .. #pnums)
	end
	if #pnums ~= #endings then
		error("For tense '" .. tense .. "', found " .. #endings .. " endings but expected " .. #pnums)
	end

	-- First, initialize any nil entries to sequences.
	for i, pnum in ipairs(pnums) do
		if data.forms[pnum .. "-" .. tense] == nil then
			data.forms[pnum .. "-" .. tense] = {}
		end
	end

	-- Now add entries
	for i = 1, #pnums do
		-- Extract endings for this person-number combo
		local ends = endings[i]
		if type(ends) == "string" then ends = {ends} end
		-- Extract prefix for this person-number combo
		local prefix = prefixes
		if type(prefix) == "table" then prefix = prefix[i] end
		-- Extract stem for this person-number combo
		local stem = stems
		if type(stem) == "table" then stem = stem[i] end
		-- Add entries for stem + endings
		for j, ending in ipairs(ends) do
			-- allow some inflections to be skipped; useful for generating
			-- partly irregular inflections
			if prefix ~= "-" and stem ~= "-" then
				local form = prefix .. stem .. ending
				if ine(form) and form ~= "-"
						-- and (not data.impers or pnums[i] == "3sg")
						then
					table.insert(data.forms[pnums[i] .. "-" .. tense], form)
				end
			end
		end
	end
end

-- Add to FORMS the inflections for the tense indicated by TENSE (the suffix
-- in the forms names, e.g. 'perf'), formed by combining the PREFIXES
-- (either a single string or a sequence of 13 strings), STEMS
-- (either a single string or a sequence of 13 strings) with the
-- ENDINGS (a sequence of 13 values, each of which is either a string
-- or a sequence of one or more possible endings). If existing
-- inflections already exist, they will be added to, not overridden.
-- If any value of PREFIXES or STEMS is the string "-", then the corresponding
-- inflection will be skipped.
function inflect_tense(data, tense, prefixes, stems, endings)
	local pnums = {"1s", "2sm", "2sf", "3sm", "3sf",
				   "2d", "3dm", "3df",
				   "1p", "2pm", "2pf", "3pm", "3pf"}
	inflect_tense_1(data, tense, prefixes, stems, endings, pnums)
end

-- Like inflect_tense() but for the imperative, which has only five forms
-- instead of 13.
function inflect_tense_impr(data, stems, endings)
	local pnums = {"2sm", "2sf", "2d", "2pm", "2pf"}
	inflect_tense_1(data, "impr", "", stems, endings, pnums)
end

-- Add VALUE (a string or array) to the end of any entries in DATA.forms[NAME],
-- initializing it to an empty array if needed.
function insert_form(data, name, value)
	if data.forms[name] == nil then
		data.forms[name] = {}
	end
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			table.insert(data.forms[name], entry)
		end
	else
		table.insert(data.forms[name], value)
	end
end

-- Insert verbal noun VN into DATA.forms["vn"], but allow it to be overridden by
-- ARGS["vn"].
function insert_verbal_noun(data, args, vn)
	insert_form(data, "vn", args["vn"] and rsplit(args["vn"], "[,،]") or vn)
end

-----------------------
-- sets of past endings
-----------------------

-- the 13 endings of the sound/hollow/geminate past tense
local past_endings = {
	-- singular
	dia.s .. "تُ", dia.s .. "تَ", dia.s .. "تِ", dia.a, dia.a .. "تْ",
	--dual
	dia.s .. "تُمَا", aa, dia.a .. "تَا",
	-- plural
	dia.s .. "نَا", dia.s .. "تُمْ",
	-- two Arabic diacritics don't work together in Wikimedia
	--dia.s .. "تُنَّ",
	dia.s .. "تُن" .. dia.sh_a, uu .. alif, dia.s .. "نَ"
}

-- make endings for final-weak past in -aytu or -awtu. AYAW is 'ay' or 'aw'
-- as appropriate. Note that AA and AW are global variables.
local function make_past_endings_ay_aw(ayaw, third_sg_masc)
	return {
	-- singular
	ayaw .. dia.s .. "تُ", ayaw ..  dia.s .. "تَ", ayaw .. dia.s .. "تِ",
	third_sg_masc, dia.a .. "تْ",
	--dual
	ayaw .. dia.s .. "تُمَا", ayaw .. aa, dia.a .. "تَا",
	-- plural
	ayaw .. dia.s .. "نَا", ayaw .. dia.s .. "تُمْ",
	-- two Arabic diacritics don't work together in Wikimedia
	--ayaw .. dia.s .. "تُنَّ",
	ayaw .. dia.s .. "تُن" .. dia.sh_a, aw .. dia.s .. alif, ayaw .. dia.s .. "نَ"
	}
end

-- past final-weak -aytu endings
local past_endings_ay = make_past_endings_ay_aw(ay, aamaq)
-- past final-weak -awtu endings
local past_endings_aw = make_past_endings_ay_aw(aw, aa)

-- Make endings for final-weak past in -ītu or -ūtu. IIUU is ī or ū as
-- appropriate. Note that AA and UU are global variables.
local function make_past_endings_ii_uu(iiuu)
	return {
	-- singular
	iiuu .. "تُ", iiuu .. "تَ", iiuu .. "تِ", iiuu .. dia.a, iiuu .. dia.a .. "تْ",
	--dual
	iiuu .. "تُمَا", iiuu .. aa, iiuu .. dia.a .. "تَا",
	-- plural
	iiuu .. "نَا", iiuu .. "تُمْ",
	-- two Arabic diacritics don't work together in Wikimedia
	--iiuu .. "تُنَّ",
	iiuu .. "تُن" .. dia.sh_a, uu .. alif, iiuu .. "نَ"
	}
end

-- past final-weak -ītu endings
local past_endings_ii = make_past_endings_ii_uu(ii)
-- past final-weak -ūtu endings
local past_endings_uu = make_past_endings_ii_uu(uu)

--------------------------------------
-- functions to inflect the past tense
--------------------------------------

--generate past verbs using specified vowel and consonant stems; works for
--sound, assimilated, hollow, and geminate verbs, active and passive
function past_2stem_conj(data, tense, v_stem, c_stem)
	inflect_tense(data, tense, "", {
		-- singular
		c_stem, c_stem, c_stem, v_stem, v_stem,
		--dual
		c_stem, v_stem, v_stem,
		-- plural
		c_stem, c_stem, c_stem, v_stem, c_stem
	}, past_endings)
end

--generate past verbs using single specified stem; works for sound and
--assimilated verbs, active and passive
function past_1stem_conj(data, tense, stem)
	past_2stem_conj(data, tense, stem, stem)
end

----------------------------------------
-- sets of non-past prefixes and endings
----------------------------------------

-- prefixes for non-past forms in -a-
local nonpast_prefixes_a = {
	-- singular
	hamza .. dia.a, "تَ", "تَ", "يَ", "تَ",
	--dual
	"تَ", "يَ", "تَ",
	-- plural
	"نَ", "تَ", "تَ", "يَ", "يَ"
}

-- prefixes for non-past forms in -u- (passive; active forms II, III, IV, Iq)
local nonpast_prefixes_u = {
	-- singular
	hamza .. dia.u, "تُ", "تُ", "يُ", "تُ",
	--dual
	"تُ", "يُ", "تُ",
	-- plural
	"نُ", "تُ", "تُ", "يُ", "يُ"
}

-- There are only five distinct endings in all non-past verbs. Make any set of
-- non-past endings given these five distinct endings.
local function make_nonpast_endings(null, fem, dual, pl, fempl)
	return {
	-- singular
	null, null, fem, null, null,
	-- dual
	dual, dual, dual,
	-- plural
	null, pl, fempl, pl, fempl
	}
end

-- endings for non-past indicative
local indic_endings = make_nonpast_endings(
	dia.u,
	dia.i .. "ينَ",
	dia.a .. "انِ",
	dia.u .. "ونَ",
	dia.s .. "نَ"
)

-- make the endings for non-past subjunctive/jussive, given the vowel diacritic
-- used in "null" endings (1s/2sm/3sm/3sf/1p)
local function make_subj_juss_endings(dia_null) 
	return make_nonpast_endings(
	dia_null,
	dia.i .. "ي",
	dia.a .. "ا",
	dia.u .. "و",
	dia.s .. "نَ"
	)
end

-- endings for non-past subjunctive
local subj_endings = make_subj_juss_endings(dia.a)

-- endings for non-past jussive
local juss_endings = make_subj_juss_endings(dia.s)

-- endings for alternative geminate non-past jussive in -a; same as subjunctive
local juss_endings_alt_a = subj_endings

-- endings for alternative geminate non-past jussive in -i
local juss_endings_alt_i = make_subj_juss_endings(dia.i)

-- endings for final-weak non-past indicative in -ā. Note that AY, AW and
-- AAMAQ are global variables.
local indic_endings_aa = make_nonpast_endings(
	aamaq,
	ay .. dia.s .. "نَ",
	ay .. dia.a .. "انِ",
	aw .. dia.s .. "نَ",
	ay .. dia.s .. "نَ"
)

-- make endings for final-weak non-past indicative in -ī or -ū; IIUU is
-- ī or ū as appropriate. Note that II and UU are global variables.
local function make_indic_endings_ii_uu(iiuu)
	return make_nonpast_endings(
	iiuu,
	ii .. "نَ",
	iiuu .. dia.a .. "انِ",
	uu .. "نَ",
	iiuu .. "نَ"
	)
end

-- endings for final-weak non-past indicative in -ī
local indic_endings_ii = make_indic_endings_ii_uu(ii)

-- endings for final-weak non-past indicative in -ū
local indic_endings_uu = make_indic_endings_ii_uu(uu)

-- endings for final-weak non-past subjunctive in -ā. Note that AY, AW, ALIF,
-- AAMAQ are global variables.
local subj_endings_aa = make_nonpast_endings(
	aamaq,
	ay .. dia.s,
	ay .. aa,
	aw .. dia.s .. alif,
	ay .. dia.s .. "نَ"
)

-- make endings for final-weak non-past subjunctive in -ī or -ū. IIUU is
-- ī or ū as appropriate. Note that AA, II, UU, ALIF are global variables.
local function make_subj_endings_ii_uu(iiuu)
	return make_nonpast_endings(
	iiuu .. dia.a,
	ii,
	iiuu .. aa,
	uu .. alif,
	iiuu .. "نَ"
	)
end

-- endings for final-weak non-past subjunctive in -ī
local subj_endings_ii = make_subj_endings_ii_uu(ii)

-- endings for final-weak non-past subjunctive in -ū
local subj_endings_uu = make_subj_endings_ii_uu(uu)

-- endings for final-weak non-past jussive in -ā
local juss_endings_aa = make_nonpast_endings(
	dia.a,
	ay .. dia.s,
	ay .. aa,
	aw .. dia.s .. alif,
	ay .. dia.s .. "نَ"
)

-- Make endings for final-weak non-past jussive in -ī or -ū. IU is short i or u,
-- IIUU is long ī or ū as appropriate. Note that AA, II, UU, ALIF are global
-- variables.
local function make_juss_endings_ii_uu(iu, iiuu)
	return make_nonpast_endings(
	iu,
	ii,
	iiuu .. aa,
	uu .. alif,
	iiuu .. "نَ"
	)
end

-- endings for final-weak non-past jussive in -ī
local juss_endings_ii = make_juss_endings_ii_uu(dia.i, ii)

-- endings for final-weak non-past jussive in -ū
local juss_endings_uu = make_juss_endings_ii_uu(dia.u, uu)

---------------------------------------
-- functions to inflect non-past tenses
---------------------------------------

-- Generate non-past conjugation, with two stems, for vowel-initial and
-- consonant-initial endings, respectively. Useful for active and passive;
-- for all forms; for all weaknesses (sound, assimilated, hollow, final-weak
-- and geminate) and for all types of non-past (indicative, subjunctive,
-- jussive) except for the imperative. (There is a separate function below
-- for geminate jussives because they have three alternants.) Both stems may
-- be the same, e.g. for sound verbs.
--
-- PREFIXES will generally be either "a" (= 'nonpast_prefixes_a', for active
-- forms I and V - X) or "u" (= 'nonpast_prefixes_u', for active forms II - IV
-- and Iq and all passive forms). Otherwise, it should be either a single string
-- (often "") or an array (table) of 13 items. ENDINGS should similarly be an
-- array of 13 items. If ENDINGS is nil or omitted, infer the endings from
-- the tense. If JUSSIVE is true, or ENDINGS is nil and TENSE indicatives
-- jussive, use the jussive pattern of vowel/consonant stems (different from the
-- normal ones).
function nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, endings, jussive)
	if prefixes == "a" then prefixes = nonpast_prefixes_a
	elseif prefixes == "u" then prefixes = nonpast_prefixes_u
	end
	if endings == nil then
		if tense == "impf" or tense == "ps-impf" then
			endings = indic_endings
		elseif tense == "subj" or tense == "ps-subj" then
			endings = subj_endings
		elseif tense == "juss" or tense == "ps-juss" then
			jussive = true
			endings = juss_endings
		else
			error("Unrecognized tense '" .. tense .."'")
		end
	end
	if not jussive then
		inflect_tense(data, tense, prefixes, {
			-- singular
			v_stem, v_stem, v_stem, v_stem, v_stem,
			--dual
			v_stem, v_stem, v_stem,
			-- plural
			v_stem, v_stem, c_stem, v_stem, c_stem
		}, endings)
	else
		inflect_tense(data, tense, prefixes, {
			-- singular
			-- 'adlul, tadlul, tadullī, yadlul, tadlul
			c_stem, c_stem, v_stem, c_stem, c_stem,
			--dual
			-- tadullā, yadullā, tadullā
			v_stem, v_stem, v_stem,
			-- plural
			-- nadlul, tadullū, tadlulna, yadullū, yadlulna
			c_stem, v_stem, c_stem, v_stem, c_stem
		}, endings)
	end
end

-- Generate non-past conjugation with one stem (no distinct stems for
-- vowel-initial and consonant-initial endings). See nonpast_2stem_conj().
function nonpast_1stem_conj(data, tense, prefixes, stem, endings, jussive)
	nonpast_2stem_conj(data, tense, prefixes, stem, stem, endings, jussive)
end

-- Generate active/passive jussive geminative. There are three alternants, two
-- with terminations -a and -i and one in a null termination with a distinct
-- pattern of vowel/consonant stem usage. See nonpast_2stem_conj() for a
-- description of the arguments.
function jussive_gem_conj(data, tense, prefixes, v_stem, c_stem)
	-- alternative in -a
	nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, juss_endings_alt_a)
	-- alternative in -i
	nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, juss_endings_alt_i)
	-- alternative in -null; requires different combination of v_stem and
	-- c_stem since the null endings require the c_stem (e.g. "tadlul" here)
	-- whereas the corresponding endings above in -a or -i require the v_stem
	-- (e.g. "tadulla, tadulli" above)
	nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, juss_endings, "jussive")
end

-----------------------------
-- sets of imperative endings
-----------------------------

-- extract the second person jussive endings to get corresponding imperative
-- endings
local function imperative_endings_from_jussive(endings)
	return {endings[2], endings[3], endings[6], endings[10], endings[11]}
end

-- normal imperative endings
local impr_endings = imperative_endings_from_jussive(juss_endings)
-- alternative geminate imperative endings in -a
local impr_endings_alt_a = imperative_endings_from_jussive(juss_endings_alt_a)
-- alternative geminate imperative endings in -i
local impr_endings_alt_i = imperative_endings_from_jussive(juss_endings_alt_i)
-- final-weak imperative endings in -ā
local impr_endings_aa = imperative_endings_from_jussive(juss_endings_aa)
-- final-weak imperative endings in -ī
local impr_endings_ii = imperative_endings_from_jussive(juss_endings_ii)
-- final-weak imperative endings in -ū
local impr_endings_uu = imperative_endings_from_jussive(juss_endings_uu)

--------------------------------------
-- functions to inflect the imperative
--------------------------------------

-- generate imperative forms for sound or assimilated verbs
function make_1stem_imperative(data, stem)
	inflect_tense_impr(data, stem, impr_endings)
end

-- generate imperative forms for two-stem verbs (hollow or geminate)
function make_2stem_imperative(data, v_stem, c_stem)
	inflect_tense_impr(data,
		{c_stem, v_stem, v_stem, v_stem, c_stem}, impr_endings)
end

-- generate imperative forms for geminate verbs form I (also IV, VII, VIII, X)
function make_gem_imperative(data, v_stem, c_stem)
	inflect_tense_impr(data,
		{v_stem, v_stem, v_stem, v_stem, c_stem}, impr_endings_alt_a)
	inflect_tense_impr(data,
		{v_stem, v_stem, v_stem, v_stem, c_stem}, impr_endings_alt_i)
	make_2stem_imperative(data, v_stem, c_stem)
end

------------------------------------
-- functions to inflect entire verbs
------------------------------------

-- Active forms II, III, IV, Iq use non-past prefixes in -u- instead of -a-.
function prefix_vowel_from_form(form)
	if form == "II" or form == "III" or form == "IV" or form == "Iq" then
		return "u"
	else
		return "a"
	end
end

-- true if the active non-past takes a-vowelling rather than i-vowelling
-- in its last syllable
function is_form56(form)
	return form == "V" or form == "VI" or form == "XV" or form == "IIq"
end

-- generate finite parts of a sound verb (also works for assimilated verbs)
-- from five stems (past and non-past, active and passive, plus imperative)
-- plus the prefix vowel in the active non-past ("a" or "u")
function make_sound_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, prefix_vowel)
	past_1stem_conj(data, "perf", past_stem)
	past_1stem_conj(data, "ps-perf", ps_past_stem)
	nonpast_1stem_conj(data, "impf", prefix_vowel, nonpast_stem)
	nonpast_1stem_conj(data, "subj", prefix_vowel, nonpast_stem)
	nonpast_1stem_conj(data, "juss", prefix_vowel, nonpast_stem)
	nonpast_1stem_conj(data, "ps-impf", "u", ps_nonpast_stem)
	nonpast_1stem_conj(data, "ps-subj", "u", ps_nonpast_stem)
	nonpast_1stem_conj(data, "ps-juss", "u", ps_nonpast_stem)
	make_1stem_imperative(data, imper_stem)
end

-- generate finite parts of a final-weak verb from five stems (past and
-- non-past, active and passive, plus imperative), five sets of
-- suffixes (past, non-past indicative/subjunctive/jussive, imperative)
-- and the prefix vowel in the active non-past ("a" or "u")
function make_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, past_suffs, indic_suffs,
		subj_suffs, juss_suffs, impr_suffs, prefix_vowel)
	inflect_tense(data, "perf", "", past_stem, past_suffs)
	inflect_tense(data, "ps-perf", "", ps_past_stem, past_endings_ii)
	nonpast_1stem_conj(data, "impf", prefix_vowel, nonpast_stem, indic_suffs)
	nonpast_1stem_conj(data, "subj", prefix_vowel, nonpast_stem, subj_suffs)
	nonpast_1stem_conj(data, "juss", prefix_vowel, nonpast_stem, juss_suffs)
	nonpast_1stem_conj(data, "ps-impf", "u", ps_nonpast_stem, indic_endings_aa)
	nonpast_1stem_conj(data, "ps-subj", "u", ps_nonpast_stem, subj_endings_aa)
	nonpast_1stem_conj(data, "ps-juss", "u", ps_nonpast_stem, juss_endings_aa)
	inflect_tense_impr(data, imper_stem, impr_suffs)
end

-- generate finite parts of a form-I final-weak verb from five
-- stems (past and non-past, active and passive, plus imperative) plus the
-- the third radical and the past and non-past vowels
function make_form_i_final_weak_verb_from_stems(data, past_stem, ps_past_stem,
		nonpast_stem, ps_nonpast_stem, imper_stem, rad3, past_vowel,
		nonpast_vowel)
	local past_suffs =
		rad3 == yaa and past_vowel == "a" and past_endings_ay or
		rad3 == waw and past_vowel == "a" and past_endings_aw or
		past_vowel == "i" and past_endings_ii or
		past_endings_uu
	local indic_suffs, subj_suffs, juss_suffs, impr_suffs
	if nonpast_vowel == "a" then
		indic_suffs = indic_endings_aa
		subj_suffs = subj_endings_aa
		juss_suffs = juss_endings_aa
		impr_suffs = impr_endings_aa
	elseif nonpast_vowel == "i" then
		indic_suffs = indic_endings_ii
		subj_suffs = subj_endings_ii
		juss_suffs = juss_endings_ii
		impr_suffs = impr_endings_ii
	else
		assert(nonpast_vowel == "u")
		indic_suffs = indic_endings_uu
		subj_suffs = subj_endings_uu
		juss_suffs = juss_endings_uu
		impr_suffs = impr_endings_uu
	end
	make_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, past_suffs, indic_suffs,
		subj_suffs, juss_suffs, impr_suffs, "a")
end

-- generate finite parts of an augmented (form II+) final-weak verb from five
-- stems (past and non-past, active and passive, plus imperative) plus the
-- prefix vowel in the active non-past ("a" or "u") and a flag indicating if
-- behave like a form V/VI verb in taking non-past endings in -ā instead of -ī
function make_augmented_final_weak_verb(data, past_stem, ps_past_stem,
		nonpast_stem, ps_nonpast_stem, imper_stem, prefix_vowel, form56)
	make_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, past_endings_ay,
		form56 and indic_endings_aa or indic_endings_ii,
		form56 and subj_endings_aa or subj_endings_ii,
		form56 and juss_endings_aa or juss_endings_ii,
		form56 and impr_endings_aa or impr_endings_ii,
		prefix_vowel)
end

-- generate finite parts of an augmented (form II+) sound or final-weak verb,
-- given the following:
--
-- DATA, ARGS = arguments from conjugation function
-- RAD3 = last radical; should be nil for final-weak verb
-- PAST_STEM_BASE = active past stem minus last syllable (= -al or -ā)
-- NONPAST_STEM_BASE = non-past stem minus last syllable (= -al/-il or -ā/-ī)
-- PS_PAST_STEM_BASE = passive past stem minus last syllable (= -il or -ī)
-- FORM -- form of verb (II to XV, Iq - IVq)
-- VN = verbal noun
function make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)

	insert_verbal_noun(data, args, vn)

	local final_weak = rad3 == nil
	local prefix_vowel = prefix_vowel_from_form(form)
	local form56 = is_form56(form)
	local a_base_suffix = final_weak and "" or dia.a .. rad3
	local i_base_suffix = final_weak and "" or dia.i .. rad3
	
	-- past and non-past stems, active and passive 
	local past_stem = past_stem_base .. a_base_suffix
	local nonpast_stem = nonpast_stem_base ..
		(form56 and a_base_suffix or i_base_suffix)
	local ps_past_stem = ps_past_stem_base .. i_base_suffix
	local ps_nonpast_stem = nonpast_stem_base .. a_base_suffix
	-- imperative stem
	local imper_stem = past_stem_base ..
		(form56 and a_base_suffix or i_base_suffix)

	-- make forms
	if final_weak then
		make_augmented_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
			ps_nonpast_stem, imper_stem, prefix_vowel, form56)
	else	
		make_sound_verb(data, past_stem, ps_past_stem, nonpast_stem,
			ps_nonpast_stem, imper_stem, prefix_vowel)
	end

	-- active and passive participle
	if final_weak then
		insert_form(data, "ap", mu .. nonpast_stem .. dia.in_)
		insert_form(data, "pp", mu .. ps_nonpast_stem .. dia.an .. amaq)
	else
		insert_form(data, "ap", mu .. nonpast_stem .. dia.un)
		insert_form(data, "pp", mu .. ps_nonpast_stem .. dia.un)
	end
end

-- generate finite parts of a hollow or geminate verb from ten stems (vowel and
-- consonant stems for each of past and non-past, active and passive, plus
-- imperative) plus the prefix vowel in the active non-past ("a" or "u"), plus
-- a flag indicating if we are a geminate verb
function make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
	ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
	ps_nonpast_c_stem, imper_v_stem, imper_c_stem, prefix_vowel, geminate)
	past_2stem_conj(data, "perf", past_v_stem, past_c_stem)
	past_2stem_conj(data, "ps-perf", ps_past_v_stem, ps_past_c_stem)
	nonpast_2stem_conj(data, "impf", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
	nonpast_2stem_conj(data, "subj", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
	nonpast_2stem_conj(data, "ps-impf", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
	nonpast_2stem_conj(data, "ps-subj", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
	if geminate then
		jussive_gem_conj(data, "juss", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
		jussive_gem_conj(data, "ps-juss", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
		make_gem_imperative(data, imper_v_stem, imper_c_stem)
	else
		nonpast_2stem_conj(data, "juss", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
		nonpast_2stem_conj(data, "ps-juss", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
		make_2stem_imperative(data, imper_v_stem, imper_c_stem)
	end
end

-- generate finite parts of an augmented (form II+) hollow verb,
-- given the following:
--
-- DATA, ARGS = arguments from conjugation function
-- RAD3 = last radical (after the hollowness)
-- PAST_STEM_BASE = invariable part of active past stem
-- NONPAST_STEM_BASE = invariable part of non-past stem
-- PS_PAST_STEM_BASE = invariable part of passive past stem
-- VN = verbal noun
-- FORM = the verb form ("IV", "VII", "VIII", "X")
function make_augmented_hollow_verb(data, args, rad3,
	past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
	insert_verbal_noun(data, args, vn)

	local form410 = form == "IV" or form == "X"
	local prefix_vowel = prefix_vowel_from_form(form)

	local a_base_suffix_v, a_base_suffix_c
	local i_base_suffix_v, i_base_suffix_c
	
	a_base_suffix_v = aa .. rad3         -- 'af-āl-a, inf-āl-a
	a_base_suffix_c = dia.a .. rad3      -- 'af-al-tu, inf-al-tu
	i_base_suffix_v = ii .. rad3         -- 'uf-īl-a, unf-īl-a
	i_base_suffix_c = dia.i .. rad3      -- 'uf-il-tu, unf-il-tu
	
	-- past and non-past stems, active and passive, for vowel-initial and
	-- consonant-initial endings
	local past_v_stem = past_stem_base .. a_base_suffix_v
	local past_c_stem = past_stem_base .. a_base_suffix_c
	-- yu-f-īl-u, ya-staf-īl-u but yanf-āl-u, yaft-āl-u
	local nonpast_v_stem = nonpast_stem_base ..
		(form410 and i_base_suffix_v or a_base_suffix_v)
	local nonpast_c_stem = nonpast_stem_base ..
		(form410 and i_base_suffix_c or a_base_suffix_c)
	local ps_past_v_stem = ps_past_stem_base .. i_base_suffix_v
	local ps_past_c_stem = ps_past_stem_base .. i_base_suffix_c
	local ps_nonpast_v_stem = nonpast_stem_base .. a_base_suffix_v
	local ps_nonpast_c_stem = nonpast_stem_base .. a_base_suffix_c

	-- imperative stem
	local imper_v_stem = past_stem_base ..
		(form410 and i_base_suffix_v or a_base_suffix_v)
	local imper_c_stem = past_stem_base ..
		(form410 and i_base_suffix_c or a_base_suffix_c)

	-- make forms
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, prefix_vowel, false)

	-- active participle
	insert_form(data, "ap", mu .. nonpast_v_stem .. dia.un)
	-- passive participle
	insert_form(data, "pp", mu .. ps_nonpast_v_stem .. dia.un)
end

-- generate finite parts of an augmented (form II+) geminate verb,
-- given the following:
--
-- DATA, ARGS = arguments from conjugation function
-- RAD3 = last radical (the one that gets geminated)
-- PAST_STEM_BASE = invariable part of active past stem; this and the stem
--   bases below will end with a consonant for forms IV, X, IVq, and a
--   short vowel for the others
-- NONPAST_STEM_BASE = invariable part of non-past stem
-- PS_PAST_STEM_BASE = invariable part of passive past stem
-- VN = verbal noun
-- FORM = the verb form ("III", "IV", "VI", "VII", "VIII", "IX", "X", "IVq")
function make_augmented_geminate_verb(data, args, rad3,
	past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
	insert_verbal_noun(data, args, vn)

	local prefix_vowel = prefix_vowel_from_form(form)

	local a_base_suffix_v, a_base_suffix_c
	local i_base_suffix_v, i_base_suffix_c
	
	if form == "IV" or form == "X" or form == "IVq" then
		a_base_suffix_v = dia.a .. rad3 .. dia.sh         -- 'af-all
		a_base_suffix_c = dia.s .. rad3 .. dia.a .. rad3  -- 'af-lal
		i_base_suffix_v = dia.i .. rad3 .. dia.sh         -- yuf-ill
		i_base_suffix_c = dia.s .. rad3 .. dia.i .. rad3  -- yuf-lil
	else
		a_base_suffix_v = rad3 .. dia.sh         -- fā-ll, infa-ll
		a_base_suffix_c = rad3 .. dia.a .. rad3  -- fā-lal, infa-lal
		i_base_suffix_v = rad3 .. dia.sh         -- yufā-ll, yanfa-ll
		i_base_suffix_c = rad3 .. dia.i .. rad3  -- yufā-lil, yanfa-lil
	end
	
	-- past and non-past stems, active and passive, for vowel-initial and
	-- consonant-initial endings
	local past_v_stem = past_stem_base .. a_base_suffix_v
	local past_c_stem = past_stem_base .. a_base_suffix_c
	local nonpast_v_stem = nonpast_stem_base ..
		(is_form56(form) and a_base_suffix_v or i_base_suffix_v)
	local nonpast_c_stem = nonpast_stem_base ..
		(is_form56(form) and a_base_suffix_c or i_base_suffix_c)
	local ps_past_v_stem = ps_past_stem_base .. i_base_suffix_v
	local ps_past_c_stem = ps_past_stem_base .. i_base_suffix_c
	local ps_nonpast_v_stem = nonpast_stem_base .. a_base_suffix_v
	local ps_nonpast_c_stem = nonpast_stem_base .. a_base_suffix_c

	-- imperative stem
	local imper_v_stem = past_stem_base ..
		(form == "VI" and a_base_suffix_v or i_base_suffix_v)
	local imper_c_stem = past_stem_base ..
		(form == "VI" and a_base_suffix_c or i_base_suffix_c)

	-- make forms
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, prefix_vowel,
		"geminate")

	-- active participle
	insert_form(data, "ap", mu .. nonpast_v_stem .. dia.un)
	-- passive participle
	insert_form(data, "pp", mu .. ps_nonpast_v_stem .. dia.un)
end

----------------------------------------
-- functions to create inflection tables
----------------------------------------

-- Test function - shows all data, see "show" function's comments
function test_forms(data, title)

	local text = "<br/>"
	for key, form in pairs(forms) do
		-- check for empty strings and nil's
		if form ~= "" and form then
			--text =  key .. [=[: {{Arab|]=] .. data.forms[key] .. [=[}}{{LR}}, ]=] 
			text = text .. key .. ": " .. data.forms[key] .. ", <br/>" 
		end
	end

   return text
end

-- Pattern matching short vowels
local re_aiu = "[" .. dia.a .. dia.i .. dia.u .. "]"
-- Pattern matching short vowels or sukūn
local re_aius = "[" .. dia.a .. dia.i .. dia.u .. dia.s .. "]"
-- Pattern matching any diacritics that may be on a consonant
local re_diacritic = dia.sh .. "?[" .. dia.a .. dia.i .. dia.u .. dia.an .. dia.in_ .. dia.un .. dia.s .. "]"

-- array of substitutions; each element is a 2-entry array FROM, TO; do it
-- this way so the concatenations only get evaluated once
local postprocess_subs = {
	-- reorder short-vowel + shadda -> shadda + short-vowel for easier processing
	{"(" .. re_aiu .. ")" .. dia.sh, dia.sh .. "%1"},

	----------same letter separated by sukūn should instead use shadda---------
	------------happens e.g. in kun-nā "we were".-----------------
	{"(.)" .. dia.s .. "%1", "%1" .. dia.sh},

	---------------------------- assimilated verbs ----------------------------
	-- iw, iy -> ī (assimilated verbs)
	{dia.i .. waw .. dia.s, ii},
	{dia.i .. yaa .. dia.s, ii},
	-- uw, uy -> ū (assimilated verbs)
	{dia.u .. waw .. dia.s, uu},
	{dia.u .. yaa .. dia.s, uu},

    -------------- final -yā uses tall alif not alif maqṣūra ------------------
    {yaa .. dia.a .. amaq, yaa .. dia.a .. alif},

	-------------------------- handle initial hamza ---------------------------
	-- initial hamza + short-vowel + hamza + sukūn -> hamza + long vowel
	{hamza .. dia.a .. hamza .. dia.s, hamza .. dia.a .. alif},
 	{hamza .. dia.i .. hamza .. dia.s, hamza .. dia.i .. yaa},
 	{hamza .. dia.u .. hamza .. dia.s, hamza .. dia.u .. waw},
	-- put initial hamza on a seat according to following vowel. alif-madda handled later.
 	{"^" .. hamza .. dia.a, hamza_on_alif .. dia.a},
 	{"^" .. hamza .. dia.i, hamza_under_alif .. dia.i},
 	{"^" .. hamza .. dia.u, hamza_on_alif .. dia.u},

	----------------------------- handle final hamza --------------------------
	-- "final" hamza may be followed by a short vowel or tanwīn sequence
	-- use a previous short vowel to get the seat
	{"(" .. re_aiu .. ")(" .. hamza .. ")(" .. re_diacritic .. "?)$",
		function(v, ham, diacrit)
			ham = v == dia.i and hamza_on_yaa or v == dia.u and hamza_on_waw or hamza_on_alif
			return v .. ham .. diacrit
		end
	},
	-- else hamza is on the line; use a special character to temporarily indicate
	-- that hamza-on-line is the final seat, not the not-yet-determined seat
	{hamza .. "(" .. re_diacritic .. "?)$",
		-- hamza_subst will be replaced with hamza (on the line) later on
		hamza_subst .. "%1"},

	---------------------------- handle medial hamza --------------------------
	-- if long vowel or diphthong precedes, we need to ignore it.
	{"([" .. alif .. waw .. yaa .. "]" .. dia.s .. "?)(" .. hamza .. ")(" .. dia.sh .. "?)(" .. re_aius .. ")",
		function(prec, ham, shad, v2)
			ham = v2 == dia.i and hamza_on_yaa or
				v2 == dia.u and hamza_on_waw or
				rfind(prec, yaa) and hamza_on_yaa or
				-- hamza_subst will be replaced with hamza (on the line) later on
				hamza_subst
			return prec .. ham ..shad .. v2
		end
	},
	-- otherwise, seat of medial hamza relates to vowels on one or both sides.
 	{"(" .. re_aius .. ")(" .. hamza .. ")(" .. dia.sh .. "?)(" .. re_aius .. ")",
		function(v1, ham, shad, v2)
			ham = (v1 == dia.i or v2 == dia.i) and hamza_on_yaa or
				(v1 == dia.u or v2 == dia.u) and hamza_on_waw or
				hamza_on_alif
			return v1 .. ham .. shad .. v2
		end
	},
	
	------------------------ finally handle alif madda ------------------------
	{hamza_on_alif .. dia.a .. alif, amad},
	
	-------------------- undo the hamza-substituted character -----------------
	{hamza_subst, hamza}
}

-- Post-process forms to eliminate phonological anomalies. Many of the changes,
-- particularly the tricky ones, involve converting hamza to have the proper
-- seat. The rules for this are complicated and are documented on the
-- [[w:Hamza]] Wikipedia page. In some cases there are alternatives allowed,
-- and we handle them below by returning multiple possibilities.
function postprocess_term(term)
	-- do the main post-processing, based on the pattern substitutions in
	-- postprocess_subs
	for _, sub in ipairs(postprocess_subs) do
		term = rsub(term, sub[1], sub[2])
	end
	-- sequence of hamza-on-waw + waw is problematic and leads to a preferred
	-- alternative with some other type of hamza, as well as the original
	-- sequence; sequence of waw + hamza-on-waw + waw is especially problematic
	-- and leads to two different alternatives with the original sequence not
	-- one of them
	if rfind(term, waw .. "ؤُو") then
		return {rsub1(term, waw .. "ؤُو", waw .. "ئُو"), rsub1(term, waw .. "ؤُو", waw .. "ءُو")}
	elseif rfind(term, yaa .. "ؤُو") then
		return {rsub1(term, yaa .. "ؤُو", yaa .. "ئُو"), term}
	elseif rfind(term, alif .. "ؤُو") then
		-- Here John Mace "Arabic Verbs" is inconsistent. In past-tense data,
		-- the preferred alternative has hamza on the line, whereas in
		-- non-past forms the preferred alternative has hamza-on-yaa even
		-- though the sequence of vowels is identical. It's too complicated to
		-- propagate information about tense through to here so pick one.
		return {rsub1(term, alif .. "ؤُو", alif .. "ئُو"), term}
	elseif rfind(term, dia.a .. "ؤُو") then
		return {rsub1(term, dia.a .. "ؤُو", dia.a .. hamza_on_alif .. dia.u .. waw), term}
	-- no alternative spelling in sequence of dia.u + hamza-on-waw + dia.u + waw;
	-- sequence of dia.i + hamza-on-waw + dia.u + waw does not occur (has
	-- hamza-on-yaa instead)
	else
		return {term}
	end
end

-- For each paradigm form, postprocess the entries, remove duplicates and
-- return the set of Arabic and transliterated Latin entries as two return
-- values.
function get_spans(form)
	if type(form) == "string" then
		form = {form}
	end
	local form_nondup = {}
	-- for each entry, postprocess it, which may potentially return
	-- multiple entries; insert each into an array, checking and
	-- omitting duplicates
	for _, entry in ipairs(form) do
		for _, e in ipairs(postprocess_term(entry)) do
			insert_if_not(form_nondup, e)
		end
	end
	-- convert each individual entry into Arabic and Latin span
	local arabic_spans = {}
	local latin_spans = {}
	for _, entry in ipairs(form_nondup) do
		table.insert(arabic_spans, entry)
		-- multiple Arabic entries may map to the same Latin entry
		-- (happens particularly with variant ways of spelling hamza)
		insert_if_not(latin_spans, ar_translit.tr(entry, nil, nil, nil))
	end
	return arabic_spans, latin_spans
end

-- Make the conjugation table. Called from export.show().
function make_table(data, title, passive, intrans)

	local forms = data.forms
	local arabic_spans_3sm_perf, _ = get_spans(forms["3sm-perf"])
	-- convert Arabic terms to spans
	for i, entry in ipairs(arabic_spans_3sm_perf) do
		arabic_spans_3sm_perf[i] = "<b lang=\"ar\" class=\"Arab\">" .. entry .. "</b>"
	end
	-- concatenate spans
	local form_3sm_perf = '<div style="display: inline-block">' ..
		table.concat(arabic_spans_3sm_perf, " <small style=\"color: #888\">or</small> ") .. "</div>"
	local title = 'Conjugation of ' .. form_3sm_perf
		.. (title and " (" .. title .. ")" or "")

	-- compute # of verbal nouns before we collapse them
	local num_vns = type(forms["vn"]) == "table" and #forms["vn"] or 1
	
	-- Format and and add transliterations to all forms
	for key, form in pairs(forms) do
		-- check for empty strings, empty arrays and nil's
		if form and #form > 0 then
			local arabic_spans, latin_spans = get_spans(form)
			-- convert Arabic terms to links
			for i, entry in ipairs(arabic_spans) do
				arabic_spans[i] = "<span lang=\"ar\" class=\"Arab\">[[" .. entry .. "]]</span>"
			end
			-- concatenate spans
			forms[key] = '<div style="display: inline-block">' .. table.concat(arabic_spans, " <small style=\"color: #888\">or</small> ") .. "</div>" .. "<br/>" ..
				"<span style=\"color: #888\">" .. table.concat(latin_spans, " <small>or</small> ") .. "</span>"
		else
			forms[key] = "&mdash;"
		end
	end

	local text = [=[<div class="NavFrame" style="width:100%">
<div class="NavHead" style="height:2.5em">]=] .. title  .. [=[</div>
<div class="NavContent">

{| border="1" color="#cdcdcd" style="border-collapse:collapse; border:1px solid #555555; background:#fdfdfd; width:100%; text-align:center" class="inflection-table"
|-
! colspan="6" style="background:#dedede" | verbal noun]=] .. (num_vns > 1 and "s" or "") .. "<br />" .. tag_text(num_vns > 1 and "المصادر" or "المصدر") .. [=[

| colspan="7" | ]=] .. links(forms["vn"]) .. [=[

|-
! colspan="6" style="background:#dedede" | active participle<br />]=] .. tag_text("اسم الفاعل") .. [=[

| colspan="7" | ]=] .. links(forms["ap"])

	if passive then
		text = text .. [=[

|-
! colspan="6" style="background:#dedede" | passive participle<br />]=] .. tag_text("اسم المفعول") .. [=[

| colspan="7" | ]=] .. links(forms["pp"])
	end

	text = text .. [=[

|-
! colspan="12" style="background:#bcbcbc" | active voice<br />]=] .. tag_text("الفعل المعلوم") .. [=[

|-
! colspan="2" style="background:#cdcdcd" | 
! colspan="3" style="background:#cdcdcd" | singular<br />]=] .. tag_text("المفرد") .. [=[

! rowspan="12" style="background:#cdcdcd;width:.5em" | 
! colspan="2" style="background:#cdcdcd" | dual<br />]=] .. tag_text("المثنى") .. [=[

! rowspan="12" style="background:#cdcdcd;width:.5em" | 
! colspan="3" style="background:#cdcdcd" | plural<br />]=] .. tag_text("الجمع") .. [=[

|-
! colspan="2" style="background:#cdcdcd" | 
! style="background:#cdcdcd" | 1<sup>st</sup> person<br />]=] .. tag_text("المتكلم") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

! style="background:#cdcdcd" | 1<sup>st</sup> person<br />]=] .. tag_text("المتكلم") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | perfect indicative<br />]=] .. tag_text("الماضي") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-perf"]) .. [=[

| ]=] .. links(forms["2sm-perf"]) .. [=[

| ]=] .. links(forms["3sm-perf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-perf"]) .. [=[

| ]=] .. links(forms["3dm-perf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-perf"]) .. [=[

| ]=] .. links(forms["2pm-perf"]) .. [=[

| ]=] .. links(forms["3pm-perf"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-perf"]) .. [=[

| ]=] .. links(forms["3sf-perf"]) .. [=[

| ]=] .. links(forms["3df-perf"]) .. [=[

| ]=] .. links(forms["2pf-perf"]) .. [=[

| ]=] .. links(forms["3pf-perf"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | imperfect indicative<br />]=] .. tag_text("المضارع") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-impf"]) .. [=[

| ]=] .. links(forms["2sm-impf"]) .. [=[

| ]=] .. links(forms["3sm-impf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-impf"]) .. [=[

| ]=] .. links(forms["3dm-impf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-impf"]) .. [=[

| ]=] .. links(forms["2pm-impf"]) .. [=[

| ]=] .. links(forms["3pm-impf"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-impf"]) .. [=[

| ]=] .. links(forms["3sf-impf"]) .. [=[

| ]=] .. links(forms["3df-impf"]) .. [=[

| ]=] .. links(forms["2pf-impf"]) .. [=[

| ]=] .. links(forms["3pf-impf"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | subjunctive<br />]=] .. tag_text("المضارع المنصوب") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-subj"]) .. [=[

| ]=] .. links(forms["2sm-subj"]) .. [=[

| ]=] .. links(forms["3sm-subj"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-subj"]) .. [=[

| ]=] .. links(forms["3dm-subj"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-subj"]) .. [=[

| ]=] .. links(forms["2pm-subj"]) .. [=[

| ]=] .. links(forms["3pm-subj"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-subj"]) .. [=[

| ]=] .. links(forms["3sf-subj"]) .. [=[

| ]=] .. links(forms["3df-subj"]) .. [=[

| ]=] .. links(forms["2pf-subj"]) .. [=[

| ]=] .. links(forms["3pf-subj"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | jussive<br />]=] .. tag_text("المضارع المجزوم") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-juss"]) .. [=[

| ]=] .. links(forms["2sm-juss"]) .. [=[

| ]=] .. links(forms["3sm-juss"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-juss"]) .. [=[

| ]=] .. links(forms["3dm-juss"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-juss"]) .. [=[

| ]=] .. links(forms["2pm-juss"]) .. [=[

| ]=] .. links(forms["3pm-juss"]) .. [=[

|-
! style="background:#dedede" | ''f''

| ]=] .. links(forms["2sf-juss"]) .. [=[

| ]=] .. links(forms["3sf-juss"]) .. [=[

| ]=] .. links(forms["3df-juss"]) .. [=[

| ]=] .. links(forms["2pf-juss"]) .. [=[

| ]=] .. links(forms["3pf-juss"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | imperative<br />]=] .. tag_text("الأمر") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | 
| ]=] .. links(forms["2sm-impr"]) .. [=[

| rowspan="2" | 

| rowspan="2" | ]=] .. links(forms["2d-impr"]) .. [=[

| rowspan="2" | 

| rowspan="2" | 
| ]=] .. links(forms["2pm-impr"]) .. [=[

| rowspan="2" | 

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-impr"]) .. [=[

| ]=] .. links(forms["2pf-impr"])

	if passive == "impers" then
		text = text .. [=[

|-
! colspan="12" style="background:#bcbcbc" | passive voice<br />]=] .. tag_text("الفعل المجهول") .. [=[

|-
| colspan="2" style="background:#cdcdcd" | 
! colspan="3" style="background:#cdcdcd" | singular<br />]=] .. tag_text("المفرد") .. [=[

| rowspan="10" style="background:#cdcdcd;width:.5em" | 
! colspan="2" style="background:#cdcdcd" | dual<br />]=] .. tag_text("المثنى") .. [=[

| rowspan="10" style="background:#cdcdcd;width:.5em" | 
! colspan="3" style="background:#cdcdcd" | plural<br />]=] .. tag_text("الجمع") .. [=[

|-
| colspan="2" style="background:#cdcdcd" | 
! style="background:#cdcdcd" | 1<sup>st</sup> person<br />]=] .. tag_text("المتكلم") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

! style="background:#cdcdcd" | 1<sup>st</sup> person<br />]=] .. tag_text("المتكلم") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | perfect indicative<br />]=] .. tag_text("الماضي") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | &mdash;

| &mdash;

| ]=] .. links(forms["3sm-ps-perf"]) .. [=[

| rowspan="2" | &mdash;

| &mdash;

| rowspan="2" | &mdash;

| &mdash;

| &mdash;

|-
! style="background:#dedede" | ''f''
| &mdash;

| &mdash;

| &mdash;

| &mdash;

| &mdash;

|-
! rowspan="2" style="background:#cdcdcd" | imperfect indicative<br />]=] .. tag_text("المضارع") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | &mdash;

| &mdash;

| ]=] .. links(forms["3sm-ps-impf"]) .. [=[

| rowspan="2" | &mdash;

| &mdash;

| rowspan="2" | &mdash;

| &mdash;

| &mdash;

|-
! style="background:#dedede" | ''f''
| &mdash;

| &mdash;

| &mdash;

| &mdash;

| &mdash;

|-
! rowspan="2" style="background:#cdcdcd" | subjunctive<br />]=] .. tag_text("المضارع المنصوب") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | &mdash;

| &mdash;

| ]=] .. links(forms["3sm-ps-subj"]) .. [=[

| rowspan="2" | &mdash;

| &mdash;

| rowspan="2" | &mdash;

| &mdash;

| &mdash;

|-
! style="background:#dedede" | ''f''
| &mdash;

| &mdash;

| &mdash;

| &mdash;

| &mdash;

|-
! rowspan="2" style="background:#cdcdcd" | jussive<br />]=] .. tag_text("المضارع المجزوم") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=]
	text = text .. [=[&mdash;

| &mdash;

| ]=] .. links(forms["3sm-ps-juss"]) .. [=[

| rowspan="2" | &mdash;

| &mdash;

| rowspan="2" | &mdash;

| &mdash;

| &mdash;

|-
! style="background:#dedede" | ''f''
| &mdash;

| &mdash;

| &mdash;

| &mdash;

| &mdash;]=]

	elseif passive then
		text = text .. [=[

|-
! colspan="12" style="background:#bcbcbc" | passive voice<br />]=] .. tag_text("الفعل المجهول") .. [=[

|-
| colspan="2" style="background:#cdcdcd" | 
! colspan="3" style="background:#cdcdcd" | singular<br />]=] .. tag_text("المفرد") .. [=[

| rowspan="10" style="background:#cdcdcd;width:.5em" | 
! colspan="2" style="background:#cdcdcd" | dual<br />]=] .. tag_text("المثنى") .. [=[

| rowspan="10" style="background:#cdcdcd;width:.5em" | 
! colspan="3" style="background:#cdcdcd" | plural<br />]=] .. tag_text("الجمع") .. [=[

|-
| colspan="2" style="background:#cdcdcd" | 
! style="background:#cdcdcd" | 1<sup>st</sup> person<br />]=] .. tag_text("المتكلم") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

! style="background:#cdcdcd" | 1<sup>st</sup> person<br />]=] .. tag_text("المتكلم") .. [=[

! style="background:#cdcdcd" | 2<sup>nd</sup> person<br />]=] .. tag_text("المخاطب") .. [=[

! style="background:#cdcdcd" | 3<sup>rd</sup> person<br />]=] .. tag_text("الغائب") .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | perfect indicative<br />]=] .. tag_text("الماضي") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-ps-perf"]) .. [=[

| ]=] .. links(forms["2sm-ps-perf"]) .. [=[

| ]=] .. links(forms["3sm-ps-perf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-ps-perf"]) .. [=[

| ]=] .. links(forms["3dm-ps-perf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-ps-perf"]) .. [=[

| ]=] .. links(forms["2pm-ps-perf"]) .. [=[

| ]=] .. links(forms["3pm-ps-perf"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-ps-perf"]) .. [=[

| ]=] .. links(forms["3sf-ps-perf"]) .. [=[

| ]=] .. links(forms["3df-ps-perf"]) .. [=[

| ]=] .. links(forms["2pf-ps-perf"]) .. [=[

| ]=] .. links(forms["3pf-ps-perf"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | imperfect indicative<br />]=] .. tag_text("المضارع") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-ps-impf"]) .. [=[

| ]=] .. links(forms["2sm-ps-impf"]) .. [=[

| ]=] .. links(forms["3sm-ps-impf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-ps-impf"]) .. [=[

| ]=] .. links(forms["3dm-ps-impf"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-ps-impf"]) .. [=[

| ]=] .. links(forms["2pm-ps-impf"]) .. [=[

| ]=] .. links(forms["3pm-ps-impf"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-ps-impf"]) .. [=[

| ]=] .. links(forms["3sf-ps-impf"]) .. [=[

| ]=] .. links(forms["3df-ps-impf"]) .. [=[

| ]=] .. links(forms["2pf-ps-impf"]) .. [=[

| ]=] .. links(forms["3pf-ps-impf"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | subjunctive<br />]=] .. tag_text("المضارع المنصوب") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=] .. links(forms["1s-ps-subj"]) .. [=[

| ]=] .. links(forms["2sm-ps-subj"]) .. [=[

| ]=] .. links(forms["3sm-ps-subj"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-ps-subj"]) .. [=[

| ]=] .. links(forms["3dm-ps-subj"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-ps-subj"]) .. [=[

| ]=] .. links(forms["2pm-ps-subj"]) .. [=[

| ]=] .. links(forms["3pm-ps-subj"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-ps-subj"]) .. [=[

| ]=] .. links(forms["3sf-ps-subj"]) .. [=[

| ]=] .. links(forms["3df-ps-subj"]) .. [=[

| ]=] .. links(forms["2pf-ps-subj"]) .. [=[

| ]=] .. links(forms["3pf-ps-subj"]) .. [=[

|-
! rowspan="2" style="background:#cdcdcd" | jussive<br />]=] .. tag_text("المضارع المجزوم") .. [=[

! style="background:#dedede" | ''m''
| rowspan="2" | ]=]
	text = text .. links(forms["1s-ps-juss"]) .. [=[

| ]=] .. links(forms["2sm-ps-juss"]) .. [=[

| ]=] .. links(forms["3sm-ps-juss"]) .. [=[

| rowspan="2" | ]=] .. links(forms["2d-ps-juss"]) .. [=[

| ]=] .. links(forms["3dm-ps-juss"]) .. [=[

| rowspan="2" | ]=] .. links(forms["1p-ps-juss"]) .. [=[

| ]=] .. links(forms["2pm-ps-juss"]) .. [=[

| ]=] .. links(forms["3pm-ps-juss"]) .. [=[

|-
! style="background:#dedede" | ''f''
| ]=] .. links(forms["2sf-ps-juss"]) .. [=[

| ]=] .. links(forms["3sf-ps-juss"]) .. [=[

| ]=] .. links(forms["3df-ps-juss"]) .. [=[

| ]=] .. links(forms["2pf-ps-juss"]) .. [=[

| ]=] .. links(forms["3pf-ps-juss"])
	end

	text = text .. [=[

|}
</div>
</div>]=]

   return text
end
 
return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
