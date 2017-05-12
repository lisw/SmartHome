---------------------------------------------------------------------
-- Compose SQL statements.
---------------------------------------------------------------------

local tconcat, tinsert = table.concat, table.insert;
local gsub, strformat = string.gsub, string.format;
local tonumber, type, pairs = tonumber, type, pairs;

---------------------------------------------------------------------
-- Checks if the argument is an number.
-- @class function
-- @name isnumber
-- @param id String with the key to check.
-- @return Boolean or Number (any number can be considered as true) or nil.
---------------------------------------------------------------------
local function isnumber(id)
	local tid = type(id);
	if tid == "string" then
		return tostring(tonumber(id)) == id;
--		return (not id:match"%a") and (tonumber(id) ~= nil);
	else
		return tid == "number";
	end;
end;

-- Checks if a table is used as an array. The keys start with one and are sequential numbers
-- @class function
-- @param t table
-- @return nil if t is not a table
-- @return false if t isn't an array
-- @return element number if t is an array
local function isarray(t)
	if type(t) ~= "table" then return nil end;

	local count=0;
	for k,v in pairs(t) do
		if type(k) ~= 'number' or k < 1 then
			return false;
		end;
		count = count + 1;
	end;
	return count == #t and count;
end;

---------------------------------------------------------------------
-- Validate a variable or column name to deny SQL injection.
-- @class function
-- @name validcolname
-- @param s String of name
-- @return raise error when s is a invalid variable name
---------------------------------------------------------------------
local function validcolname(s)
	if type(s) ~= "string" or s:find("[^%w_]") then
		error("Invalid column name: " .. s or "");
	end;
end;

---------------------------------------------------------------------
-- Validate a condition key name to deny SQL injection.
-- @class function
-- @name validkeyname
-- @param s String of name
-- @return raise error when s is a invalid key name
---------------------------------------------------------------------
local function validkeyname(s)
	if type(s) ~= "string" or s:find("[^%w_%(%s%)%*]") then
		error("Invalid key name: " .. s or "");
	end;
end;

---------------------------------------------------------------------
-- Quote a value to be included in an SQL statement.
-- @class function
-- @name quote
-- @param s String or number (numbers aren't quoted).
-- @return String with prepared value.
---------------------------------------------------------------------
local function quote(s)
	if not s then return end;
	if isnumber(s) then return s; end;
	return "'" .. gsub(s, "(['\\])", "\\%1") .. "'";
end;

---------------------------------------------------------------------
-- Builds a list of pairs field=value, separated by commas.
-- The '=' sign could be changed by the kvsep argument.
-- The ',' could also be changed by the pairssep argument.
-- The value is escape by quote.
-- @class function
-- @name fullconcat
-- @param tab Table of field=value pairs.
-- @param kvsep String with key-value separator (default = '=').
-- @param pairssep String with pairs separator (default = ',').
-- @return String with field=value pairs separated by ','.
---------------------------------------------------------------------
local function fullconcat(tab, kvsep, pairssep)
	local formatstring = "%s"..(kvsep or '=').."%s";
	local l = {};
	for key, val in pairs (tab) do
		validkeyname(key);
		tinsert(l, strformat(formatstring, key, quote(val)));
	end;
	return tconcat(l, pairssep or ',');
end;

-- Builds a condition string for where-clause or having-clause
-- @param cond Table of name=value pairs
-- @return String " AND " concat all conditions
--   ex: "address LIKE 'g%' AND age>36" for cond={address='g%',age='>36'}
local function andconcat(cond)
	if type(cond) ~= "table" then return cond; end;

	local l = {};
	local fmt = "%s%s%s";
	for k, v in pairs(cond) do
		validkeyname(k);
		local op2 = v:sub(1,2);
		local op  = op2:sub(1,1);
		local v1,v2 = v:match("^(.+)%.%.(.+)$");
		if v1 then
			op = " BETWEEN ";
			v  = strformat(fmt, quote(v1), " AND ", quote(v2));
		elseif op2==">=" or op2=="<=" or op2=="!=" then
			op = op2;
			v  = quote(v:sub(3));
		elseif op==">" or op=="<" then
			v  = quote(v:sub(2));
		elseif v == "null" or v == "not null" then
			op = " is ";
		else
			op = v:match("%%") and " LIKE " or "=";
			v  = quote(v);
		end;
		tinsert(l, strformat(fmt, k, op, v));
	end;
	return tconcat(l, " AND ");
end;

-- Builds a string with a WHERE conditions.
-- If the cond is given, the string " WHERE " is added as a prefix.
-- @class function
-- @name where
-- @param cond String with where-clause or key list (optional).
-- @return String with WHERE conditions.
local function where(cond, prefix)
	local count = isarray(cond);
	if count then
		if count == 0 then
			cond = nil;
		elseif count == 1 then
			cond = cond[1];
		else
			for k,v in pairs(cond) do
				cond[k] = andconcat(v);
			end;
			cond = "(" .. tconcat(cond, ") OR (") .. ")";
		end;
	end;
	cond = andconcat(cond);
	return cond and ((prefix or " WHERE ") .. cond) or "";
end;

---------------------------------------------------------------------
-- Builds a string with a SELECT command.
-- The string "SELECT " is added as a prefix.
-- If the tabname is given, the string " FROM " is added as a prefix.
-- If the cond is given, the string " WHERE " is added as a prefix.
-- @class function
-- @name select
-- @param tabname String with table name.
-- @param cond String with where-clause or key list (optional).
-- @param columns String or columns list (optional).
-- @param groubby String or columns list (optional).
-- @param having String with having-clause or key list (optional).
-- @param orderby String or columns list (optional).
-- @param rowcount Integer (optional).
-- @param offset Integer (optional).
-- @return String with SELECT command.
---------------------------------------------------------------------
local function select(tabname, cond, columns, groupby, having, orderby, rowcount, offset)
	local sql, error_params;
	local unknown_params = {};
	local function getparam(param)
		local typ = type(cond);
		if typ == "string" then
			return quote(cond);
		elseif typ == "table" then
			local val = cond[param];
			if val then return quote(val); end;
		end;
		tinsert(unknown_params, param);
		error_params = true;
	end;

	if type(tabname) == "string" and tabname:sub(1,7):lower():match("select%s") then
		sql = tabname:gsub("?([%w_]+)", getparam);
		rowcount, offset, columns = columns, groupby;
		if error_params then
			error("Unknown parameters: " .. tconcat(unknown_params, ",") .. "@" .. tabname);
		end;
	else
		columns = type(columns) == "table" and tconcat(columns, ",") or columns or "*";
		tabname = tabname and (" FROM "..tabname) or "";
		groupby = type(groupby) == "table" and tconcat(groupby, ",") or groupby;
		orderby = type(orderby) == "table" and tconcat(orderby, ",") or orderby;
		sql = strformat("SELECT %s%s%s%s%s%s", columns, tabname, where(cond),
			groupby and (" GROUP BY " .. groupby) or "",
			where(having, " HAVING "),
			orderby and (" ORDER BY " .. orderby) or "");
	end;

	return strformat("%s LIMIT %s,%s", sql, tonumber(offset) or 0, tonumber(rowcount) or 500), columns;
end;

---------------------------------------------------------------------
-- Builds a string with an INSERT command.
-- @class function
-- @name insert
-- @param tabname String with table name or with the SQL text that
--	follows the "INSERT INTO" prefix.
-- @param values Table of elements to be inserted (optional).
-- @return String with INSERT command.
---------------------------------------------------------------------
local function insert(tabname, values, prefix)
	local columns;
	if type(values) == "table" then
		local k, v = {}, {};
		local i = 0;
		for key, val in pairs(values) do
			validcolname(key);
			i = i+1;
			k[i] = key; v[i] = quote(val);
		end;
		columns = tconcat(k, ",");
		values = strformat("(%s) VALUES(%s)", columns, tconcat(v, ","));
	end;
	if not values or #values==0 then
		error("Empty values");
	end;
	return strformat("%s%s%s", prefix or "INSERT INTO ", tabname, values), columns;
end;

---------------------------------------------------------------------
-- Builds a string with an REPLACE command.
-- @class function
-- @name replace
-- @param tabname String with table name or with the SQL text that
--	follows the "REPLACE INTO" prefix.
-- @param values Table of elements to be inserted (optional).
-- @return String with REPLACE command.
---------------------------------------------------------------------
local function replace(tabname, values)
	return insert(tabname, values, "REPLACE INTO ");
end;

---------------------------------------------------------------------
-- Builds a string with an UPDATE command.
-- @class function
-- @name update
-- @param tabname String with table name.
-- @param values Table of elements to be updated.
-- @param cond String with where-clause (and following SQL text).
-- @return String with UPDATE command.
---------------------------------------------------------------------
local function update(tabname, values, cond)
	local columns;
	if type(values) == "table" then
		local k = {};
		local i = 0;
		for key,_ in pairs(values) do
			validcolname(key);
			i = i+1;
			k[i] = key;
		end;
		columns = tconcat(k, ",");
		values = fullconcat(values, "=", ",");
	end;
	if not values or #values==0 then
		error("Empty values");
	end;
	return strformat("UPDATE %s SET %s%s", tabname, values, where(cond)), columns;
end;

---------------------------------------------------------------------
-- Builds a string with a DELETE command.
-- @class function
-- @name delete
-- @param tabname String with table name.
-- @param cond String with where-clause (and following SQL text).
-- @return String with DELETE command.
---------------------------------------------------------------------
local function delete(tabname, cond)
	return strformat("DELETE FROM %s%s", tabname, where(cond));
end;

---------------------------------------------------------------------
-- Builds a string of SQL statement
-- @class function
-- @name build
-- @param pkt table of database access command packet.
-- @return String of SQL statement, Column names affected
-- @return Table of SQL statement, if Multiple commands in packet
-- @property readonly in pkt indicating SQL statement is select
local function build(pkt)
    local cmd = type(pkt) == "table" and pkt.cmd;
    if not cmd then
        error "Empty database access command!";
    elseif isarray(cmd) then
        if #cmd == 1 then
            pkt.cmd = nil;
            for k,v in pairs(cmd[1]) do
                pkt[k] = v;
            end;
            return build(pkt);
        end;

        local rw=0;
        for i,c in ipairs(cmd) do
            c.sql,c.cols = build(c);
            rw = rw + (not c.ro and 1 or 0);
        end;
        pkt.ro = rw==0 or nil;
        return cmd;
    end;
    local keys = pkt.keys;
    local vals = pkt.values;
    local cols = pkt.columns;
    local tbl  = pkt.table;
    local sql  = pkt.sql;
    sql = type(sql)=="string" and cmd=="select" and sql:sub(1,7):lower():match("select%s") and sql;

    if not sql and cmd ~= "log" and (not tbl or tbl:find("[^%w_]")) then
        error "Error table name!";
    end;
    if cmd == "select" then
        pkt.ro = true;
        if sql then
            sql = select(sql, pkt.params, pkt.rowcount, pkt.offset);
            local s,e = sql:lower():find("%s+from%s+");
            if s then
                cols = sql:sub(8,s-1);
                s,e,tbl = sql:find("(%S+)", e+1);
                pkt.table = tbl;
            end;
            return sql, cols;
        end;
        return select(tbl, keys, cols, pkt.groupby,pkt.having,pkt.orderby,pkt.rowcount,pkt.offset);
    elseif cmd == "insert" then
        return insert(tbl, vals);
    elseif cmd == "replace" then
        return replace(tbl, vals);
    elseif cmd == "delete" then
        return delete(tbl, keys);
    elseif cmd == "update" then
        return update(tbl, vals, keys);
    elseif cmd == "log" and pkt.level and pkt.class and pkt.message then
        pkt.vals = {class=pkt.class,level=pkt.level,message=pkt.message,app=pkt.app,user=pkt.user,ip=pkt.ip};
        return insert("log", pkt.vals);
    else
        error("Unknown database access command: " .. (cmd or ""));
    end;
end;

--------------------------------------------------------------------------------
return {
	quote = quote,
	isnumber = isnumber,
	isarray  = isarray,
	concat = fullconcat,
	where  = where,

	select = select,
	insert = insert,
	replace= replace,
	update = update,
	delete = delete,
	where  = where,
	build  = build,
}
