ARCHITECTURE fsm_controller_a OF fsm_controller_e IS

    CONSTANT person_in_c   : std_logic_vector(number_byte-1 downto 0) := "1" & x"2C" & '0'; -- +
    CONSTANT person_out_c  : std_logic_vector(number_byte-1 downto 0) := "1" & x"2D" & '0'; -- -
    CONSTANT person_stop_c : std_logic_vector(number_byte-1 downto 0) := "1" & x"21" & '0'; -- !
    
    TYPE statetype_t IS (idle,operation,person_going_in,person_going_out,person_stop, person_in, person_out, person_went_in, person_went_out);
    SIGNAL state_machine_st : statetype_t;
    SIGNAL sensor_reg_s     :  std_logic_vector(number_sens - 1 downto 0);
    -- interface signals 
    SIGNAL sdi_s         : std_logic; 
    SIGNAL sdv_s         : std_logic;
    SIGNAL stx_s         : std_logic;
    SIGNAL ledG_s        : std_logic;
    SIGNAL ledR_s        : std_logic;
    SIGNAL ledV_s        : std_logic;
    SIGNAL txd_cnt_s     : integer range number_byte downto 0;
    SIGNAL txt_reg_s     : std_logic_vector(number_byte downto 0);
    SIGNAL txd_s         : std_logic;    
    SIGNAL b9k6_s        : std_logic;
    SIGNAL per_cnt_s     : integer range Xmax downto 0;
    SIGNAL sens_1_s      : std_logic; 
    SIGNAL sens_2_s      : std_logic; 
    SIGNAL sens_3_s      : std_logic; 
    SIGNAL end_stop_s    : std_logic;
    
    -- components
    COMPONENT baud9k6_e 
        GENERIC(
            baudrate  : integer := 1250
         ); 
        PORT(clk_i  : in std_logic;
	         rst_n_i  : in std_logic;
	         en_o   : out std_logic );
	END COMPONENT;
	COMPONENT valid_led_gen_e
	    GENERIC(
            one_second : integer := 12000000
        );
	   PORT ( clk_i : in  std_logic; 
              rst_n_i : in  std_logic; -- active low
              led_o : out std_logic );
	END COMPONENT;
    COMPONENT sens_debounce_e
      GENERIC(
            ms_delay    : integer := 60
      );
      PORT (clk_i   : in std_logic; 
            rst_n_i : in std_logic; 
            p_b_i   : in std_logic;
            sens_o  : out  std_logic
      );
	END COMPONENT;
BEGIN

 -- drive pins
 sensor_reg_s <= sens_1_s & sens_2_s & sens_3_s; 
 sdi_o      <= sdi_s;
 sdv_o      <= sdv_s;
 stx_o      <= stx_s;
 txd_o      <= txd_s;
 txtled_o   <= txd_s;
 ledG_o     <= ledG_s;
 ledR_o     <= ledR_s;
 
 -- components instantiation
 br : baud9k6_e
 GENERIC MAP(
    baudrate => baudrate
 )
 PORT MAP(
    clk_i   => clk_i,
    rst_n_i => rst_n_i,
    en_o    => b9k6_s
 );
 
 sec : valid_led_gen_e
 GENERIC MAP(
    one_second => one_second
 )
 PORT MAP(
    clk_i      => clk_i,
    rst_n_i    => rst_n_i,
    led_o      => ledV_o
 );

deb_1 : sens_debounce_e
GENERIC MAP(
    ms_delay => ms_delay
)
PORT MAP(
    clk_i    => clk_i, 
    rst_n_i  => rst_n_i, 
    p_b_i    => sens_1_i,
    sens_o   => sens_1_s
);

deb_2 : sens_debounce_e
GENERIC MAP(
    ms_delay => ms_delay
)
PORT MAP(
    clk_i    => clk_i, 
    rst_n_i  => rst_n_i, 
    p_b_i    => sens_2_i,
    sens_o   => sens_2_s
);

deb_3 : sens_debounce_e
GENERIC MAP(
    ms_delay => ms_delay
)
PORT MAP(
    clk_i    => clk_i, 
    rst_n_i  => rst_n_i, 
    p_b_i    => sens_3_i,
    sens_o   => sens_3_s
);

-----------------------------------------------------

stm_PROC : PROCESS(rst_n_i,clk_i)
BEGIN
        IF(rst_n_i = '0')THEN
             state_machine_st <= idle;
             sdi_s            <= '0'; 
             sdv_s            <= '0';
             stx_s            <= '0';
             txd_cnt_s        <= 0;
             txd_s            <= '1';    
             per_cnt_s        <= 0;
             txt_reg_s        <= (others => '0');
             end_stop_s       <= '0';
				 ledG_s				<=	'0';
				 ledR_s				<=	'0';
        ELSIF(rising_edge(clk_i))THEN
            IF(cl_i = '1')then
                per_cnt_s <= 0;
                ledG_s    <= '1';
                ledR_s    <= '0';
                end_stop_s <= '0';
                state_machine_st <= idle;
                txd_cnt_s     <= 0;
                txd_s         <= '1';    
                per_cnt_s     <=  0;
                txt_reg_s     <= (others => '0');
            ELSE               
                CASE state_machine_st IS
                    WHEN idle =>
                         sdi_s         <= '0'; 
                         sdv_s         <= '0';
                         stx_s         <= '0';
                         ledG_s        <= '1';
                         ledR_s        <= '0';
                         txd_cnt_s     <= 0;
                         txd_s         <= '1';    
                         per_cnt_s     <= 0;
                         txt_reg_s     <= (others => '0');
                         IF(sensor_reg_s /= "000")THEN
                            state_machine_st <= operation;
                         END IF;
                    WHEN operation =>
                         IF(sensor_reg_s = "100")THEN
                            state_machine_st <= person_going_in;
                            txt_reg_s <= '0' & person_in_c;
                         ELSIF(sensor_reg_s = "001")THEN
                            state_machine_st <= person_going_out;
                            txt_reg_s <= '0' & person_out_c;
                         ELSE
                            state_machine_st <= operation;
                         END IF;
                         IF(per_cnt_s >= Xmax)THEN
                            state_machine_st <= person_stop;
                            txt_reg_s <= '0' & person_stop_c;
                            ledR_s <= '1';
                            ledG_s <= '0';
                         ELSE
                            ledG_s <= '1';
                            ledR_s <= '0';
                         END IF;
                         txd_s         <= '1';  
                         end_stop_s    <= '0';     
                   WHEN person_going_in =>
                        IF(sensor_reg_s = "010")THEN
                           state_machine_st <= person_in;
                        ELSE
                           state_machine_st <= person_going_in;
                        END IF;
                        ledR_s <= '1';
                        ledG_s <= '0'; 
                   WHEN person_in =>
                        IF(sensor_reg_s = "001")THEN
                           state_machine_st <= person_went_in;
                        ELSE
                           state_machine_st <= person_in;
                        END IF;
                   WHEN person_went_in =>
                        IF(b9k6_s = '1')THEN
                            txd_s      <= txt_reg_s(txd_cnt_s);
                            IF( txd_cnt_s >= number_byte)THEN
                                txd_cnt_s <= 0;
                                per_cnt_s <= per_cnt_s + 1; 
                                txd_s <= '1'; 
                                state_machine_st <= operation;                          
                            ELSE
                                txd_cnt_s <= txd_cnt_s + 1;
                            END IF;
                        END IF;
                   WHEN person_going_out =>
                        ledR_s <= '1';
                        ledG_s <= '0';
                        end_stop_s <= '0';     
                        IF(sensor_reg_s = "010")THEN
                           state_machine_st <= person_out;
                        ELSE
                           state_machine_st <= person_going_out;
                        END IF; 
                   WHEN person_out =>
                        IF(sensor_reg_s = "100")THEN
                           state_machine_st <= person_went_out;
                        ELSE
                           state_machine_st <= person_out;
                        END IF; 
                   WHEN person_went_out =>
                         IF(b9k6_s = '1')THEN
                            txd_s      <= txt_reg_s(txd_cnt_s);
                            IF( txd_cnt_s >= number_byte)THEN
                                txd_cnt_s <= 0;
                                per_cnt_s <= per_cnt_s - 1;
                                txd_s <= '1';  
                                state_machine_st <= operation;                          
                            ELSE
                                txd_cnt_s <= txd_cnt_s + 1;
                            END IF;
                        END IF;  
                   WHEN person_stop =>
                         ledR_s <= '1';
                         ledG_s <= '0';

                         IF(b9k6_s = '1')THEN
                            txd_s      <= txt_reg_s(txd_cnt_s);
                            IF( txd_cnt_s >= number_byte)THEN
                                IF(end_stop_s = '1')THEN
                                    state_machine_st <= person_going_out;
                                    txt_reg_s <= '0' & person_out_c;
                                ELSE
                                    state_machine_st <= person_stop;
                                END IF;
                                txd_cnt_s <= 0;
                                txd_s <= '1';  
                            ELSE
                                txd_cnt_s <= txd_cnt_s + 1;
                            END IF;
                        END IF;
                        IF (sensor_reg_s = "001")THEN
                            end_stop_s <= '1';
                        END IF;                     
                   WHEN others =>
                        NULL;
               END CASE;
          END IF;              
        END IF;  
END PROCESS;
END fsm_controller_a;